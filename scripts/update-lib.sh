# shellcheck shell=bash
# Shared by the update-*.sh scripts: collect problems/notes as the script
# runs, print them at the end. Problems don't stop the script.
warnings=()
notes=()

finish() {
  echo
  if (( ${#warnings[@]} )); then
    echo "Done, with problems:"
    printf '  ! %s\n' "${warnings[@]}"
  else
    echo "Done. Restart updated apps to use the new versions."
  fi
  (( ${#notes[@]} )) && printf '  > %s\n' "${notes[@]}"
  (( ${#warnings[@]} == 0 ))
}
