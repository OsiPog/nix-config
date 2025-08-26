{
  config,
  lib,
  ...
}:
with config.stylix.fonts; {
  programs.vscode.profiles.default.userSettings = {
    "editor.fontSize" = lib.mkForce sizes.applications;
    "debug.console.fontSize" = lib.mkForce sizes.applications;
    "markdown.preview.fontSize" = lib.mkForce sizes.applications;
    "terminal.integrated.fontSize" = lib.mkForce sizes.applications;
    "chat.editor.fontSize" = lib.mkForce sizes.applications;
  };
}
