CfhighlanderTemplate do

  # Name 'application-loadbalancer'
  DependsOn 'lib-ec2'

  Parameters do
    ComponentParam 'EnvironmentName', 'dev', isGlobal: true
    ComponentParam 'EnvironmentType', 'development', isGlobal: true
    ComponentParam 'DnsDomain', isGlobal: true
    ComponentParam 'HostedZoneId', ''
    ComponentParam 'SubnetIds', type: 'CommaDelimitedList'
    ComponentParam 'VPCId', type: 'AWS::EC2::VPC::Id'
    ComponentParam 'SslCertId', ''
  end

end
