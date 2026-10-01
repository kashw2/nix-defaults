_: {
  flake.processComposeModules.proxies = {
    services.nginx."proxies:nginx".enable = true;
  };
}
