# application-loadbalancer CfHighlander component

[![Build Status](https://travis-ci.com/theonestack/hl-component-application-loadbalancer.svg?branch=master)](https://travis-ci.com/theonestack/hl-component-application-loadbalancer)

## Parameters

| Name | Use | Default | Global | Type | Allowed Values |
| ---- | --- | ------- | ------ | ---- | -------------- |
| EnvironmentName | Tagging | dev | true | string
| EnvironmentType | Tagging | development | true | string | ['development','production']
| VPCId | Security Groups | None | false | AWS::EC2::VPC::Id
| DnsDomain | DNS domain to use | None | true | string
| SubnetIds | list of subnets | None | false | CommaDelimitedList
| SslCertId | ACM certificate ID | None | false | string (arn)
| WebACLArn | ACL to use on the load balancer | None | false | string
| HostedZoneId | Route53 Zone ID | None | false | string (arn)

`HostedZoneId` is ONLY used if `use_zone_id` is True.



## Outputs/Exports

| Name | Value | Exported |
| ---- | ----- | -------- |
| {tg_name}TargetGroup | Target Group Name | true
| {listener_name}Listener | Listener Name | true
| LoadBalancer | Load Balancer ARN | true
| SecurityGroup | Security Group name | true
| LoadBalancerDNSName | Load Balancer URL | true
| LoadBalancerCanonicalHostedZoneID | Load Balancer Hosted Zone ID | true

## Included Components

[lib-ec2](https://github.com/theonestack/hl-component-lib-ec2)

## Example Configuration
### Highlander
    Component name: 'applicationloadbalancer', template: 'application-loadbalancer' do
        parameter name: 'DnsDomain', value: root_domain
        parameter name: 'SubnetIds', value: cfout('vpcv2', 'PublicSubnets')
        parameter name: 'VPCId', value: cfout('vpcv2', 'VPCId')
        parameter name: 'SslCertId', value: cfout('acmv2', 'CertificateArn')
    end

### Load Balancer Configuration

    loadbalancer_scheme: public
    dns_format: ${EnvironmentName}.${DnsDomain}
    use_zone_id: false

    records:
      - lb

      listeners:
      http:
        port: 80
        protocol: http
        default:
          action:
            targetgroup: web

            targetgroups:
            publicDefault:
            protocol: http
            port: 80
            tags:
            Name: Default-HTTP
            web:
            protocol: http
            type: ip
            port: 80
            healthcheck:
            path: "/"
            interval: 15
            timeout: 5
            healthy_count: 5
            unhealthy_count: 4
            code: '200'
            tags:
            Name:
            Fn::Sub: ${EnvironmentName}-app
            attributes:
            deregistration_delay.timeout_seconds: 30

            security_group_rules:
            -
            protocol: tcp
            from: 80
            to: 80
            ip_blocks:
            - ops
            - dev
            - public




## Cfhighlander Setup

install cfhighlander [gem](https://github.com/theonestack/cfhighlander)

```bash
gem install cfhighlander
```

or via docker

```bash
docker pull theonestack/cfhighlander
```
## Testing Components

Running the tests

```bash
cfhighlander cftest application-loadbalancer
```
