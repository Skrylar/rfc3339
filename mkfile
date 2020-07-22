module=rfc3339

t:
    mkdir t

t/$module.t: src/$module.nim
    nim c -o:$target $prereq

check:V: t/$module.t
    prove

push:V:
    git push github

