def rule_actions(actions)
  response = []
  actions.each do |action,config|
    case action
    when 'targetgroup'
      response << forward(config)
    when 'redirect'
      response << redirect(config)
    when 'fixed'
      response << fixed(config)
    end
  end
  return response
end

def forward(value)
  return { Type: "forward", TargetGroupArn: Ref("#{value}TargetGroup") }
end

def redirect(value)
  case value
  when 'http_to_https'
    return http_to_https_redirect()
  else
    return { Type: "redirect", RedirectConfig: value }
  end
end

def fixed(value)
  response = { Type: 'fixed-response', FixedResponseConfig: {}}
  response[:FixedResponseConfig][:ContentType] = value['type'] if value.has_key?'type'
  response[:FixedResponseConfig][:MessageBody] = value['body'] if value.has_key? 'body'
  response[:FixedResponseConfig][:StatusCode] = value['code']
  return response
end

def http_to_https_redirect()
  return { Type: "redirect",
    RedirectConfig: {
      Host: '#{host}',
      Path: '/#{path}',
      Port: '443',
      Protocol: 'HTTPS',
      Query: '#{query}',
      StatusCode: 'HTTP_301'
    }
  }
end
