cd /home/claude/nk-identity
echo "[" > /tmp/modules.json; first=1
for d in $(cat /tmp/vfiles.txt | xargs -n1 dirname | sort -u); do
  cd /home/claude/nk-identity/$d
  for f in *.v; do
    [ -e "$f" ] || continue; b="${f%.v}"
    case "$b" in chk_*|q_*|s|cz|ax|PE_fix|P27_fix) continue;; esac
    compiled=0; [ -f "$b.vo" ] && compiled=1
    thms=$(grep -oE "^ *(Theorem|Lemma|Corollary) +[A-Za-z0-9_']+" "$f" | awk '{print $2}')
    n=$(echo "$thms" | wc -w); c=0; a=0
    if [ "$compiled" = "1" ] && [ "$n" -gt 0 ]; then
      mod=$(grep -oE "^Module +[A-Za-z0-9_']+" "$f" | head -1 | awk '{print $2}')
      { echo "Require Import $b."; for t in $thms; do echo "Print Assumptions ${mod:+$mod.}$t."; done; } > /tmp/sw.v
      out=$(timeout 300 coqc -Q . "" /tmp/sw.v 2>&1)
      c=$(echo "$out" | grep -c 'Closed under the global context')
      a=$(echo "$out" | grep -cE '^(Axioms|Variables)')
    fi
    [ $first -eq 0 ] && echo "," >> /tmp/modules.json; first=0
    printf '{"path":"%s/%s","compiled":%s,"results":%s,"closed":%s,"with_axioms":%s}' \
      "${d#./}" "$f" "$compiled" "$n" "$c" "$a" >> /tmp/modules.json
  done
done
echo "" >> /tmp/modules.json; echo "]" >> /tmp/modules.json
