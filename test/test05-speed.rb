#! /usr/bin/ruby

for size in 1..9 do
  tc = 0
  for iter in 1..5 do
    t = Time.now
    system('luatex  "\count300=' + (5*size).to_s() + '\input test05-speed.tex" &> /dev/null')
    t = Time.now - t
    tc = tc + t
    printf("%3d\t%10.5f\n", 5*size, t)
  end
end
