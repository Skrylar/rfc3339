module=rfc3339

t:
    mkdir t

t/$module.t: src/$module.nim
    nim c -o:$target $prereq

# should be `prove` but this was written on the standard unittest harness
# i haven't converted it to TAP yet
check:V: t/$module.t
    ./t/$module.t

push:V:
    git push github

