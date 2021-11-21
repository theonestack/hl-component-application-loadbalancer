CloudFormation do

  default_tags = {}
  default_tags["Environment"] = Ref(:EnvironmentName)
  default_tags["EnvironmentType"] = Ref(:EnvironmentType)

  sg_tags = default_tags.clone
  sg_tags['Name'] = FnSub("${EnvironmentName}-#{external_parameters[:loadbalancer_scheme]}-loadbalancer")

  loadbalancer_name = external_parameters.fetch(:loadbalancer_name, '')
  security_group_rules = external_parameters.fetch(:security_group_rules, [])
  ip_blocks = external_parameters.fetch(:ip_blocks, [])

  EC2_SecurityGroup(:SecurityGroup) do
    GroupDescription FnJoin(' ', [Ref(:EnvironmentName), "#{external_parameters[:component_name]}"])
    VpcId Ref(:VPCId)
    SecurityGroupIngress generate_security_group_rules(security_group_rules,ip_blocks) if (!security_group_rules.empty? && !ip_blocks.empty?)
    Tags sg_tags.map { |key,value| { Key: key, Value: value } }
  end

  attributes = []
  loadbalancer_attributes = external_parameters.fetch(:loadbalancer_attributes, {})
  loadbalancer_attributes.each do |key, value|
    attributes << { Key: key, Value: value } unless value.nil?
  end

  loadbalancer_tags = default_tags.clone
  loadbalancer_tags['Name'] = (!loadbalancer_name.empty?) ? FnSub(loadbalancer_name) : FnSub("${EnvironmentName}-#{external_parameters[:loadbalancer_scheme]}")
  tags = external_parameters.fetch(:tags, {})
  tags.each { |key, value| loadbalancer_tags[key] = value }


  ElasticLoadBalancingV2_LoadBalancer(:LoadBalancer) do
    Name FnSub(loadbalancer_name) if !loadbalancer_name.empty?
    Type 'application'
    Scheme 'internal' if external_parameters[:loadbalancer_scheme] == 'internal'
    Subnets Ref(:SubnetIds)
    SecurityGroups [Ref(:SecurityGroup)]
    Tags loadbalancer_tags.map { |key,value| { Key: key, Value: value }}
    LoadBalancerAttributes attributes if attributes.any?
  end


  targetgroups = external_parameters.fetch(:targetgroups, {})
  targetgroups.each do |tg_name, tg|

    tg_tags = default_tags.clone
    tg_tags['Name'] = FnSub("${EnvironmentName}-#{tg_name}")
    if (tg.has_key?('tags')) and (!tg['tags'].nil?)
      tg['tags'].each { |key, value| tg_tags[key] = value }
    end

    ElasticLoadBalancingV2_TargetGroup("#{tg_name}TargetGroup") do
      ## Required
      Port tg['port']
      Protocol tg['protocol'].upcase
      VpcId Ref(:VPCId)
      ## Optional
      if tg.has_key?('healthcheck')
        HealthCheckPort tg['healthcheck']['port'] if tg['healthcheck'].has_key?('port')
        HealthCheckProtocol tg['healthcheck']['protocol'].upcase if tg['healthcheck'].has_key?('protocol')
        HealthCheckIntervalSeconds tg['healthcheck']['interval'] if tg['healthcheck'].has_key?('interval')
        HealthCheckTimeoutSeconds tg['healthcheck']['timeout'] if tg['healthcheck'].has_key?('timeout')
        HealthyThresholdCount tg['healthcheck']['healthy_count'] if tg['healthcheck'].has_key?('healthy_count')
        UnhealthyThresholdCount tg['healthcheck']['unhealthy_count'] if tg['healthcheck'].has_key?('unhealthy_count')
        HealthCheckPath tg['healthcheck']['path'] if tg['healthcheck'].has_key?('path')
        Matcher ({ HttpCode: tg['healthcheck']['code'] }) if tg['healthcheck'].has_key?('code')
      end

      TargetType tg['type'] if tg.has_key?('type')
      TargetGroupAttributes tg['attributes'].map { |key, value| { Key: key, Value: value } } if tg.has_key?('attributes')
      Tags tg_tags.map { |key,value| { Key: key, Value: value }}

      if tg.has_key?('type') and tg['type'] == 'ip' and tg.has_key? 'target_ips'
        Targets (tg['target_ips'].map {|ip|  { 'Id' => ip['ip'], 'Port' => ip['port'] }})
      end
    end

    Output("#{tg_name}TargetGroup") {
      Value(Ref("#{tg_name}TargetGroup"))
      Export FnSub("${EnvironmentName}-#{external_parameters[:component_name]}-#{tg_name}TargetGroup")
    }
  end


  listeners = external_parameters.fetch(:listeners, {})
  listeners.each do |listener_name, listener|
    next if listener.nil? || (listener.has_key?('enabled') && listener['enabled'] == false)

    ElasticLoadBalancingV2_Listener("#{listener_name}Listener") do
      Protocol listener['protocol'].upcase
      Certificates [{ CertificateArn: Ref('SslCertId') }] if listener['protocol'].upcase == 'HTTPS'
      SslPolicy listener['ssl_policy'] if listener.has_key?('ssl_policy')
      Port listener['port']
      DefaultActions rule_actions(listener['default']['action'])
      LoadBalancerArn Ref(:LoadBalancer)
    end

    if (listener.has_key?('certificates')) && (listener['protocol'].upcase == 'HTTPS')
      listener['certificates'].each_with_index do |cert, index|
        #is the cert is a ref to a stack param add a condtion to allow an empty ref
        #assumes when you want to pass the ref to the cert arn you'll only have FnSub ref
        is_cert_a_param = false
        if /\${.*}/.match?(cert)
          is_cert_a_param = true
          Condition("EnableCert#{index}", FnNot(FnEquals(FnSub(cert), "")))
        end

        listener_cert_name = "#{listener_name}ListenerCertificate"
        if index > 0
          listener_cert_name = "#{listener_name}ListenerCertificate#{index}"
        end

        ElasticLoadBalancingV2_ListenerCertificate(listener_cert_name) do
          Condition "EnableCert#{index}" if is_cert_a_param
          Certificates [{ CertificateArn: FnSub(cert) }]
          ListenerArn Ref("#{listener_name}Listener")
        end
      end
    end

    listener['rules'].each_with_index do |rule, index|

      if rule.key?("name")
        rule_name = rule['name']
      elsif rule['priority'].is_a? Integer
        rule_name = "#{listener_name}Rule#{rule['priority']}"
      else
        rule_name = "#{listener_name}Rule#{index}"
      end

      ElasticLoadBalancingV2_ListenerRule(rule_name) do
        Actions rule_actions(rule['actions'])
        Conditions rule_conditions(rule['conditions'])
        ListenerArn Ref("#{listener_name}Listener")
        Priority rule['priority']
      end

    end if listener.has_key?('rules')

    Output("#{listener_name}Listener") {
      Value(Ref("#{listener_name}Listener"))
      Export FnSub("${EnvironmentName}-#{external_parameters[:component_name]}-#{listener_name}Listener")
    }
  end

  records = external_parameters.fetch(:records, [])
  use_zone_id = external_parameters[:use_zone_id]
  dns_format = external_parameters[:dns_format]
  records.each do |record|
    name = (['apex',''].include? record) ? dns_format : "#{record}.#{dns_format}."

    Route53_RecordSet("#{record.gsub('*','Wildcard').gsub('.','Dot').gsub('-','')}LoadBalancerRecord") do

      if use_zone_id == true
        HostedZoneId Ref(:HostedZoneId)
      else 
        HostedZoneName FnSub("#{dns_format}.")
      end
      
      Name FnSub(name)
      Type 'A'
      AliasTarget ({
          DNSName: FnGetAtt(:LoadBalancer, :DNSName),
          HostedZoneId: FnGetAtt(:LoadBalancer, :CanonicalHostedZoneID)
      })
    end
  end

  Condition(:AssociateWebACL, FnNot(FnEquals(Ref(:WebACLArn), '')))

  WAFv2_WebACLAssociation(:WebACLAssociation) {
    Condition :AssociateWebACL
    ResourceArn Ref(:LoadBalancer)
    WebACLArn Ref(:WebACLArn)
  }

  Output(:LoadBalancer) {
    Value(Ref(:LoadBalancer))
    Export FnSub("${EnvironmentName}-#{external_parameters[:component_name]}-LoadBalancer")
  }

  Output(:SecurityGroup) {
    Value(Ref(:SecurityGroup))
    Export FnSub("${EnvironmentName}-#{external_parameters[:component_name]}-SecurityGroupLoadBalancer")
  }

  Output(:LoadBalancerDNSName) {
    Value(FnGetAtt(:LoadBalancer, :DNSName))
    Export FnSub("${EnvironmentName}-#{external_parameters[:component_name]}-DNSName")
  }

  Output(:LoadBalancerCanonicalHostedZoneID) {
    Value(FnGetAtt(:LoadBalancer, :CanonicalHostedZoneID))
    Export FnSub("${EnvironmentName}-#{external_parameters[:component_name]}-CanonicalHostedZoneID")
  }

end
