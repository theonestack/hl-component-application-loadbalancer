CfhighlanderTemplate do

  # Name 'application-loadbalancer'

  Parameters do
    ComponentParam 'EnvironmentName', 'dev', isGlobal: true
    ComponentParam 'EnvironmentType', 'development', isGlobal: true
    ComponentParam 'DnsDomain', isGlobal: true
    ComponentParam 'SubnetIds', type: 'CommaDelimitedList'
    ComponentParam 'VPCId', type: 'AWS::EC2::VPC::Id'
  end

end
