# k9s skin template, linked to ~/.config/omarchy/themed/k9s.yaml.tpl by mise.omarchy.toml.
# Omarchy renders it from the theme's colors.toml on every theme change (a theme that ships its
# own k9s.yaml wins); omarchy-skin.hook copies the result to ~/.config/k9s/skins/current.yaml.
# Backgrounds stay "default" so k9s sits on the terminal's own themed background.
k9s:
  body:
    fgColor: '{{ foreground }}'
    bgColor: default
    logoColor: '{{ accent }}'
    logoColorMsg: '{{ foreground }}'
    logoColorInfo: '{{ green }}'
    logoColorWarn: '{{ yellow }}'
    logoColorError: '{{ red }}'
  prompt:
    fgColor: '{{ foreground }}'
    bgColor: default
    suggestColor: '{{ muted }}'
    border:
      command: '{{ accent }}'
      default: '{{ green }}'
  help:
    fgColor: '{{ foreground }}'
    bgColor: default
    sectionColor: '{{ green }}'
    keyColor: '{{ accent }}'
    numKeyColor: '{{ magenta }}'
  frame:
    title:
      fgColor: '{{ cyan }}'
      bgColor: default
      highlightColor: '{{ magenta }}'
      counterColor: '{{ yellow }}'
      filterColor: '{{ green }}'
    border:
      fgColor: '{{ muted }}'
      focusColor: '{{ accent }}'
    menu:
      fgColor: '{{ foreground }}'
      keyColor: '{{ accent }}'
      numKeyColor: '{{ magenta }}'
    crumbs:
      fgColor: '{{ background }}'
      bgColor: '{{ cyan }}'
      activeColor: '{{ accent }}'
    status:
      newColor: '{{ cyan }}'
      modifyColor: '{{ blue }}'
      addColor: '{{ green }}'
      pendingColor: '{{ orange }}'
      errorColor: '{{ red }}'
      highlightColor: '{{ bright_cyan }}'
      killColor: '{{ magenta }}'
      completedColor: '{{ muted }}'
  info:
    fgColor: '{{ yellow }}'
    sectionColor: '{{ foreground }}'
    cpuColor: '{{ cyan }}'
    memColor: '{{ magenta }}'
    k9sRevColor: '{{ green }}'
  views:
    table:
      fgColor: '{{ foreground }}'
      bgColor: default
      cursorFgColor: '{{ background }}'
      cursorBgColor: '{{ accent }}'
      markColor: '{{ yellow }}'
      header:
        fgColor: '{{ yellow }}'
        bgColor: default
        sorterColor: '{{ cyan }}'
        selectedSortColumnColor: '{{ magenta }}'
    xray:
      fgColor: '{{ foreground }}'
      bgColor: default
      cursorColor: '{{ accent }}'
      cursorTextColor: '{{ background }}'
      graphicColor: '{{ magenta }}'
    charts:
      bgColor: default
      dialBgColor: default
      chartBgColor: default
      focusFgColor: '{{ background }}'
      focusBgColor: '{{ accent }}'
      defaultDialColors:
        - '{{ green }}'
        - '{{ red }}'
      defaultChartColors:
        - '{{ green }}'
        - '{{ red }}'
      resourceColors:
        cpu:
          - '{{ cyan }}'
          - '{{ blue }}'
        mem:
          - '{{ magenta }}'
          - '{{ yellow }}'
    yaml:
      keyColor: '{{ accent }}'
      valueColor: '{{ foreground }}'
      colonColor: '{{ muted }}'
    picker:
      mainColor: '{{ foreground }}'
      focusColor: '{{ accent }}'
      shortcutColor: '{{ cyan }}'
    logs:
      fgColor: '{{ foreground }}'
      bgColor: default
      indicator:
        fgColor: '{{ accent }}'
        bgColor: default
        toggleOnColor: '{{ green }}'
        toggleOffColor: '{{ muted }}'
  dialog:
    fgColor: '{{ foreground }}'
    bgColor: default
    buttonFgColor: '{{ foreground }}'
    buttonBgColor: '{{ muted }}'
    buttonFocusFgColor: '{{ background }}'
    buttonFocusBgColor: '{{ accent }}'
    labelFgColor: '{{ yellow }}'
    fieldFgColor: '{{ foreground }}'
