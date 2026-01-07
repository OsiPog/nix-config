{
  writeShellApplication,
  jq,
  ...
}:
writeShellApplication {
  name = "get-hypr-monitors-conf";
  runtimeInputs = [jq];
  text = ''
    hyprctl monitors -j \
      | jq '.[]
        | "desc:\(.description)"
        + ", \(.width)x\(.height)@\(.refreshRate)"
        + ", \(.x)x\(.y)"
        + ", \(.scale)"
        + (if .transform != 0 then ", transform, \(.transform)" else "" end)
        + (if .vrr then ", vrr, 1" else "" end)
        + (if .mirrorOf != "none" then ", mirror, \(.mirrorOf)" else "" end)
        + (if .disabled then ", disabled" else "" end)
      '
  '';
}
