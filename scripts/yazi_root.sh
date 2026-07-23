#!/usr/bin/env bash
set -euo pipefail

# tmux retains the X11 forwarding variables from the attached SSH client.
if [[ -n ${SSH_CONNECTION:-} && -n ${TMUX:-} ]]; then
  for variable in DISPLAY XAUTHORITY; do
    value="$(tmux show-environment "$variable" 2>/dev/null || true)"
    case "$value" in
      "$variable"=*) export "$variable=${value#*=}" ;;
    esac
  done
fi

# Background Yazi tasks have no interactive stdin, so process X11 events
# without entering ROOT's interactive command loop.
YAZI_ROOT_MACROS="$(printf '%s\n' "$@")" exec root.exe -l -e 'TString macros(gSystem->Getenv("YAZI_ROOT_MACROS")); auto entries = macros.Tokenize("\n"); for (int index = 0; index < entries->GetEntriesFast(); ++index) { auto path = ((TObjString*)entries->At(index))->GetString(); int canvas_count = gROOT->GetListOfCanvases()->GetSize(); gROOT->Macro(path.Data()); TString title(gSystem->BaseName(path)); int seen = 0; TIter next(gROOT->GetListOfCanvases()); while (auto canvas = (TCanvas*)next()) { if (seen++ >= canvas_count) canvas->SetTitle(title.Data()); } } delete entries; while (true) { gSystem->ProcessEvents(); gSystem->Sleep(100); }'
