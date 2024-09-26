inputs: let 
  overlaySet = {
    example = import ./example;
    tmux = import ./tmux;
  };
  # import them above, and the name from the set
  # and inputs will be passed to them,
  # and they will be returned as a list
  # by the next statement
in
builtins.attrValues (builtins.mapAttrs (name: value: (value name inputs)) overlaySet)
