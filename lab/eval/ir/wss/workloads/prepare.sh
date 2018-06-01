echo '

set $cold=200m
set $hot=800m

define process name=filereader,instances=1
{
  thread name=cold,memsize=$cold,instances=1
  {
    flowop hog name=cold,value=262144,workingset=$cold,iosize=4
  }
  thread name=hot,memsize=$hot,instances=1
  {
    flowop eventlimit name=limit
    flowop hog name=hot,value=262144,workingset=$hot,iosize=4
  }
}

create files
'
