CfhighlanderTemplate do

  # Name 'application-loadbalancer'
  DependsOn 'lib-ec2'
  DependsOn 'lib-alb'

  Parameters do
    ComponentParam 'EnvironmentName', 'dev', isGlobal: true
    ComponentParam 'EnvironmentType', 'development', isGlobal: true
    ComponentParam 'DnsDomain', isGlobal: true
    ComponentParam 'SubnetIds', type: 'CommaDelimitedList'
    ComponentParam 'VPCId', type: 'AWS::EC2::VPC::Id'
    ComponentParam 'SslCertId', ''
    ComponentParam 'WebACLArn', ''
    ComponentParam 'UserPoolId', ''
    ComponentParam 'UserPoolClientId', ''
    ComponentParam 'UserPoolDomainName', ''
    
    if use_zone_id == true
      ComponentParam 'HostedZoneId', ''
    end
  end

end
