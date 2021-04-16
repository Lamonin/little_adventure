program path_find_1;

uses GraphABC, ABCObjects, Timers;
type
entity = record
  obj:ObjectABC;
  x:integer; y:integer; //Наличие и необходимость этих полей под вопросом
end;

cord = record x:integer; y:integer; end;
cord_arr = array [1..16, 1..26] of cord;
dot = record
  x:integer; y:integer; can_get:boolean;
end;

var enemy, target:entity; edge_zone:PictureABC;
    points : array [1..16,1..26] of dot;
    
function build_path(n:dot):dot;
begin
  writeln(n);
  result := n;
end;

{Возвращает СПИСОК соседних (.) в которые можно из текущей}
function GetDotNeighbors(var p:dot):List<dot>;
var temp:List<dot>;
begin
  temp:= new List<dot>();
  var i:=p.y; var j:=p.x;
  if (i-1>0) and points[i-1,j].can_get then
    temp.Add(points[i-1,j]);
  
  if (i+1<17) and points[i+1,j].can_get then
    temp.Add(points[i+1,j]);
  
  if (j-1>0) and points[i,j-1].can_get then
    temp.Add(points[i,j-1]);

  if (j+1<27) and points[i,j+1].can_get then
    temp.Add(points[i,j+1]);
    
  result:=temp;
end;

function choose_node(nodes:List<dot>; f:dot):dot;
var min, w:real;
    best:dot;
begin
  min:=99999;
  nodes.ForEach(procedure(n) -> 
  begin
    w:=sqrt(sqr(f.x-n.x)+(f.y-n.y));
    if w<min then begin
      min:=w; best:=n;
    end;
  end);
  choose_node := best;
end;

function find_path(start, finish:dot):dot;
var open, close, new_open:List<dot>;
    node:dot;
begin
  open:= new List<dot>();
  close:= new List<dot>();
  open.Add(start);
  
  while open.Count<>0 do begin
    node := choose_node(open, finish);
    
    if (node = finish) then begin
      build_path(node);
      writeln('ПУТЬ НАЙДЕН');
      exit;
    end;
    
    open.Remove(node);
    close.Add(node);
    
    new_open:= GetDotNeighbors(node);
    new_open:= new_open.Except(close).ToList();
    new_open.ForEach(procedure(n) -> 
    begin
      if not (open.Contains(n)) then begin
        n.prev.x := node.x; n.prev.y:=node.y;
        open.Add(n);
      end;
    end);
    
  end;
end;

procedure EnemyMove(e:entity);
begin
  var e_x := round(e.obj.Position.X / 48);
  var e_y := round(e.obj.Position.Y / 48);
  var t_x := round(target.obj.Position.X / 48);
  var t_y := round(target.obj.Position.Y / 48);
  
  var path := find_path(points[e_y,e_x],points[t_y,t_x]);
end;

{Update - цикл (таймер) обработки игровых событий}
procedure Update();
begin
  EnemyMove(enemy);
  //Sleep(33); //Без неё не будет работать таймер
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
  while(true) do begin
    Update();
    Sleep(32);
  end;
//  var t := Timer.Create(33, Update);
//  t.Start();
end.