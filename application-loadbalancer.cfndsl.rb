CloudFormation do
  private = false
  if defined?(loadbalancer_scheme) && loadbalancer_scheme == 'internal'
    private = true
  end

  default_tags = {}
  default_tags["EnvironmentName"] = Ref(:EnvironmentName)
  default_tags["EnvironmentType"] = Ref(:EnvironmentType)

  sg_tags = default_tags.clone
  sg_tags['Name'] = FnSub("${EnvironmentName}-#{loadbalancer_scheme}-loadbalancer")

  EC2_SecurityGroup(:SecurityGroup) do
    GroupDescription FnJoin(' ', [Ref(:EnvironmentName), component_name])
    VpcId Ref(:VPCId)
    Tags sg_tags.map { |key,value| { Key: key, Value: value } }
  end

  atributes = []
  loadbalancer_attributes.each do |key, value|
    atributes << { Key: key, Value: value } unless value.nil?
  end if defined? loadbalancer_attributes

  loadbalancer_tags = default_tags.clone
  loadbalancer_tags['Name'] = (defined? loadbalancer_name) ? FnSub(loadbalancer_name) : FnSub("${EnvironmentName}-#{loadbalancer_scheme}")
  if defined? tags and !tags.nil?
    tags.each { |key, value| loadbalancer_tags[key] = value }
  end

  ElasticLoadBalancingV2_LoadBalancer(:LoadBalancer) do
    Name FnSub(loadbalancer_name) if defined? loadbalancer_name
    Type 'application'
    Scheme 'internal' if private
    Subnets Ref(:SubnetIds)
    SecurityGroups [Ref(:SecurityGroup)]
    Tags loadbalancer_tags.map { |key,value| { Key: key, Value: value }}
    LoadBalancerAttributes atributes if atributes.any?
  end

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
        HealthCheckProtocol tg['healthcheck']['protocol'] if tg['healthcheck'].has_key?('port')
        HealthCheckIntervalSeconds tg['healthcheck']['interval'] if tg['healthcheck'].has_key?('interval')
        HealthCheckTimeoutSeconds tg['healthcheck']['timeout'] if tg['healthcheck'].has_key?('timeout')
        HealthyThresholdCount tg['healthcheck']['healthy_count'] if tg['healthcheck'].has_key?('healthy_count')
        UnhealthyThresholdCount tg['healthcheck']['unhealthy_count'] if tg['healthcheck'].has_key?('unhealthy_count')
        HealthCheckPath tg['healthcheck']['path'] if tg['healthcheck'].has_key?('path')
        Matcher ({ HttpCode: tg['healthcheck']['code'] }) if tg['healthcheck'].has_key?('code')
      end

      TargetType tg['type'] if tg.has_key?('type')
      TargetGroupAttributes tg['atributes'].map { |key, value| { Key: key, Value: value } } if tg.has_key?('atributes')
      Tags tg_tags.map { |key,value| { Key: key, Value: value }}

      if tg.has_key?('type') and tg['type'] == 'ip' and tg.has_key? 'target_ips'
        Targets (tg['target_ips'].map {|ip|  { 'Id' => ip['ip'], 'Port' => ip['port'] }})
      end
    end

    Output("#{tg_name}TargetGroup") {
      Value(Ref("#{tg_name}TargetGroup"))
      Export FnSub("${EnvironmentName}-#{component_name}-#{tg_name}TargetGroup")
    }
  end if defined? targetgroups

  listeners.each do |listener_name, listener|
    next if listener.nil?

    ElasticLoadBalancingV2_Listener("#{listener_name}Listener") do
      Protocol listener['protocol'].upcase
      Certificates [{ CertificateArn: FnSub(listener['default']['certificate']) }] if listener['protocol'].upcase == 'HTTPS'
      SslPolicy listener['ssl_policy'] if listener.has_key?('ssl_policy')
      Port listener['port']
      DefaultActions rule_actions(listener['default']['action'])
      LoadBalancerArn Ref(:LoadBalancer)
    end

    if (listener.has_key?('certificates')) && (listener['protocol'] == 'https')
      ElasticLoadBalancingV2_ListenerCertificate("#{listener_name}ListenerCertificate") {
        Certificates listener['certificates'].map { |certificate| { CertificateArn: FnSub(certificate) }  }
        ListenerArn Ref("#{listener_name}Listener")
      }
    end

    listener['rules'].each do |rule|

      ElasticLoadBalancingV2_ListenerRule("#{listener_name}Rule#{rule['priority']}") do
        Actions rule_actions(rule['actions'])
        Conditions rule_conditions(rule['conditions'])
        ListenerArn Ref("#{listener_name}Listener")
        Priority rule['priority'].to_i
      end

    end if listener.has_key?('rules')

    Output("#{listener_name}Listener") {
      Value(Ref("#{listener_name}Listener"))
      Export FnSub("${EnvironmentName}-#{component_name}-#{listener_name}Listener")
    }
  end if defined? listeners

  records.each do |record|
    name = (['apex',''].include? record) ? dns_format : "#{record}.#{dns_format}."
    Route53_RecordSet("#{record.gsub('*','Wildcard').gsub('.','Dot').gsub('-','')}LoadBalancerRecord") do
      HostedZoneName FnSub("#{dns_format}.")
      Name FnSub(name)
      Type 'A'
      AliasTarget ({
          DNSName: FnGetAtt(:LoadBalancer, :DNSName),
          HostedZoneId: FnGetAtt(:LoadBalancer, :CanonicalHostedZoneID)
      })
    end
  end if defined? records

  Output(:LoadBalancer) {
    Value(Ref(:LoadBalancer))
    Export FnSub("${EnvironmentName}-#{component_name}-LoadBalancer")
  }

  Output(:SecurityGroup) {
    Value(Ref(:SecurityGroup))
    Export FnSub("${EnvironmentName}-#{component_name}-SecurityGroupLoadBalancer")
  }

  Output(:LoadBalancerDNSName) {
    Value(FnGetAtt(:LoadBalancer, :DNSName))
    Export FnSub("${EnvironmentName}-#{component_name}-DNSName")
  }

  Output(:LoadBalancerCanonicalHostedZoneID) {
    Value(FnGetAtt(:LoadBalancer, :CanonicalHostedZoneID))
    Export FnSub("${EnvironmentName}-#{component_name}-CanonicalHostedZoneID")
  }

end
