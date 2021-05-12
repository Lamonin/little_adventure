{main.pas - главный файл проекта. В нём игра начинается,
заканчивается и обрабатывается.}

{$reference engine/Vector2.dll}
{$reference engine/JSONParser.dll}

program main;
uses GraphABC, ABCObjects;
uses LAEngine in 'engine\LAEngine.pas';

begin
  //ПЕРВОНАЧАЛЬНЫЕ НАСТРОЙКИ ПРОЕКТА
  SetConsoleIO();
  var t := new Player(100, 200, 24, 64, 10, 10, 'nothing');
  var m := new JSONFile('json2.json');
  writeln(m.GetValue('object.master'));
  m.SetValue('object.chief.nene.cocu.pupu.huhu', 2015);
  //writeln(m.GetValue('object.chief.nene.cucu'));
  m.SaveFile();
  
  Sleep(1000);
  t.ShowMessage(3000, MsgType.Question);
  t.pos := new V2(300, 400);
  Sleep(3000);
  t.ShowMessage(3000, MsgType.Attention);
  t.pos := new V2(200, 300);
  Sleep(3000);
  t.ShowMessage(3000, MsgType.Dialog);
  
  //ЦИКЛ ОБРАБОТКИ ИГРОВОЙ ЛОГИКИ
  while (true) do begin
    
  end;
end.