program path_find_1;

uses GraphABC, ABCObjects, Timers;
type
entity = record
  obj:ObjectABC;
  x:integer; y:integer; //Наличие и необходимость этих полей под вопросом
end;
dot = record
  x:integer; y:integer; can_get:boolean; neighbors:List<dot>;
end;

var enemy, target:entity; edge_zone:PictureABC;
    points : array [1..16,1..26] of dot;

function find_path(start, finish:dot):dot;
begin
  
end;

procedure EnemyMove(e:entity);
begin
  var e_x := round(e.obj.Position.X / 48);
  var e_y := round(e.obj.Position.Y / 48);
  var t_x := round(target.obj.Position.X / 48);
  var t_y := round(target.obj.Position.Y / 48);
  
  var path := find_path(points[e_y,e_x],points[t_y,t_x]);
end;

{Задает точке соседние (.) в которые можно из неё попасть}
procedure ChooseNeighbors(var p:dot);
begin
  var i:=p.y; var j:=p.x;
  p.neighbors := new List<dot>();
  if (i-1>0) and points[i-1,j].can_get then
    p.neighbors.Add(points[i-1,j]);
  if (i+1<16) and points[i+1,j].can_get then
    p.neighbors.Add(points[i+1,j]);
  if (j-1>0) and points[i,j-1].can_get then
    p.neighbors.Add(points[i,j-1]);
  if (j+1<26) and points[i,j+1].can_get then
    p.neighbors.Add(points[i,j+1]);
end;

{Update - цикл (таймер) обработки игровых событий}
procedure Update();
begin
  EnemyMove(enemy);
  Sleep(16); //Без неё не будет работать таймер
end;

begin
  {Применение настроек окна}
  Window.Width:=1248;
  Window.Height:=768;
  CenterWindow();
  SetWindowIsFixedSize(true);
  SetConsoleIO(); //ВАЖНО
  {========================}
  
  {Загружаем и сохраняем в памяти карту границ.}
  edge_zone := PictureABC.Create(0,0,'obstacle_ver_2.png');
  
  {Создаем сетку доступных путей на уровне}
  for var i:=1 to 16 do begin
    for var j:=1 to 26 do begin
      var x:=24+48*(j-1);
      var y:=24+48*(i-1);
      var r_rect := RectangleABC.Create(x-4,y-4, 8, 8, clRed);
      
      if not (r_rect.Intersect(edge_zone)) then begin
        r_rect.Color:=clLime;
        points[i,j].x := j; points[i,j].y:=i;
        points[i,j].can_get := true;
        ChooseNeighbors(points[i,j]);
      end;
    end;
  end;
  {=======================================}
  
  
  {Создаем и располагаем на поле врага и цель}
  enemy.x := 142; enemy.y:=220;
  enemy.obj := RectangleABC.Create(enemy.x, enemy.y, 24, 48, clRed);
  target.x:= 384; target.y:= 524;
  target.obj := RectangleABC.Create(target.x, target.y, 24, 24, clOrange);
  
  {Запускаем таймер обработки событий}
  var t := Timer.Create(16, Update);
  t.Start();
end.