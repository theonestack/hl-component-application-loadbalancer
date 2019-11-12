def rule_conditions(conditions)
  response = []
  conditions.each do |condition,config|
    case condition
    when 'path'
      response << path(config)
    when 'host'
      response << host_header(config)
    when 'header'
      response << http_header(config['name'],config['values'])
    when 'method'
      response << http_request_method(config)
    end
  end
  return response
end

def path(values)
  return { Field: "path-pattern", PathPatternConfig: { Values: wrap(values) }}
end

def host_header(values)
  return { Field: "host-header", HostHeaderConfig: { Values: wrap(values) }}
end

def http_header(name,values)
  return { Field: "http-header", HttpHeaderConfig: { HttpHeaderName: name, Values: wrap(values) }}
end

def http_request_method(values)
  return { Field: "http-request-method", HttpRequestMethodConfig: { Values: wrap(values) }}
end

def wrap(values)
  if values.is_a?(Hash) && values.has_key?('Fn::Split')
    return values
  end
  
  [values].flatten()
end
