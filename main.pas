{main.pas - главный файл проекта. В нём игра начинается,
заканчивается и обрабатывается.}

{$reference engine/Vector2.dll}

program main;
uses GraphABC, ABCObjects;
uses LAEngine in 'engine\LAEngine.pas';

begin
  //ПЕРВОНАЧАЛЬНЫЕ НАСТРОЙКИ ПРОЕКТА
  SetConsoleIO();
  var t := new Player(100,200, 24, 64, 10, 10, 'nothing');
  writeln(t.pos.x, t.pos.y:4);
  
  writeln(t.pos.NMultiple(10).x, t.pos.NMultiple(10).y : 2);
  writeln(t.pos.magnitude);
  
  Sleep(512);
  t.pos += new V2(100, 100);
  
  Sleep(512);
  t.pos -= new V2(0, 200);
  t.ShowMessage(2000, MsgType.Question);
  
  Sleep(512);
  t.pos += new V2(224, 11);
  t.ShowMessage(2000, MsgType.Attention);
  writeln(t.pos.x, t.pos.y:4);
  
  Sleep(512);
  t.pos += new V2(0, 200);
  
  //ЦИКЛ ОБРАБОТКИ ИГРОВОЙ ЛОГИКИ
  while (true) do begin
    
  end;
end.