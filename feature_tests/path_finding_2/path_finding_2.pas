uses GraphABC, ABCObjects;

type
cord = record x:integer; y:integer; end;

Vector2 = class
  public
    x,y:real;
    constructor (x_c,y_c:real);
    begin
      x:=x_c; y:=y_c;
    end;
    
    {Возвращает округленный до ближайших целых значений Vector2}
    function IntVector():cord;
    begin
      var c:cord; c.x:= round(x); c.y:=round(y);
      Result:=c;
    end;
    
    {Нормализация Vector2 - вещественное число}
    function Normalize():Vector2;
    begin
       var v2:Vector2 := new Vector2(0,0);
       var l := sqrt(sqr(x) + sqr(y));
       if l<>0 then begin
         v2.x := 1/l * x; v2.y := 1/l * y;
       end;
       Result:=v2;
    end;
    
    {Длина Vector2 - вещественное число}
    function Length():real;
    begin
      Result:=sqrt(sqr(x)+sqr(y));
    end;
end;

Enemy = class
  private
    x,y,w,h:integer;
    obj:ObjectABC;
  public
    constructor (xc, yc, wc, hc:integer);
    begin
      x := xc; y := yc; w := wc; h:=hc;
      obj := RectangleABC.Create(x - w div 2,y - h div 2, w, h, clRed);
    end;
    
    procedure MoveOn(x_c,y_c, speed:integer);
    begin
      x+=x_c; y+=y_c;
      obj.MoveTo(x-w div 2, y-h div 2);
    end;
    
    function GetCrossPoint():cord;
    var c:cord;
    begin
      c.x:= round(x / 48); c.y:= round(y / 48);
      Result:=c;
    end;
    
    function Pos():cord;
    begin
      var c:cord; c.x:=x; c.y:=y;
      Result := c;
    end;
end;
entity = record
  obj:ObjectABC;
  x:integer; y:integer; //Наличие и необходимость этих полей под вопросом
end;
p_path = ^dot;

dot = record
  x:integer; y:integer; can_get:boolean; h:real; g:real; f:real; prev:p_path;
end;

var enemy_one:Enemy; target:entity; edge_zone:PictureABC;
    points : array [1..16,1..26] of dot;
    
function build_path(n:dot):dot;
begin
  if n.prev <> nil then
    while (n.prev^.prev <> nil) do begin
      //writeln(n.x, n.y:3);
      n := n.prev^;
      end;
  
  result := n;
end;

{Возвращает СПИСОК соседних (.) в которые можно попасть из текущей}
function GetDotNeighbors(var p:dot):List<dot>;
var temp:List<dot>;
begin
  temp:= new List<dot>();
  var i:=p.y; var j:=p.x;
  if (i-1>0) and (i-1<17) and points[i-1,j].can_get then
    temp.Add(points[i-1,j]);
  
  if (i+1>0) and (i+1<17) and points[i+1,j].can_get then
    temp.Add(points[i+1,j]);
  
  if (j-1>0) and (j-1<27) and points[i,j-1].can_get then
    temp.Add(points[i,j-1]);

  if (j+1>0) and (j+1<27) and points[i,j+1].can_get then
    temp.Add(points[i,j+1]);
    
  result:=temp;
end;
procedure DeleteFromList(var l:List<dot>; n:dot);
begin
  for var i := 0 to l.Count-1 do
    if (n.x = l[i].x) and (n.y = l[i].y) then begin
      l.RemoveAt(i);
      exit;
    end;
end;

function IsInList(n:dot; l:List<dot>):boolean;
begin
  for var i := 0 to l.Count-1 do
    if (n.x = l[i].x) and (n.y = l[i].y) then begin
      Result:= true;
      exit;
    end;
  Result := false;
end;

function nodeWeight(n, f:dot):real;
begin
  result:=sqrt(sqr(f.x-n.x)+(f.y-n.y));
end;

function choose_node(nodes:List<dot>; f:dot):dot;
var min, w:real;
    best:dot;
begin
  min:=99999;
  nodes.ForEach(procedure(n) -> 
  begin
    w:=nodeWeight(n,f);
    if w<min then begin
      min:=w; best:=n;
    end;
  end);
  choose_node := best;
end;

function find_path(start, finish:dot):dot;
var open, close, new_open:List<dot>;
begin
  start.g := 0;
  start.h := nodeWeight(start,finish);
  start.f := start.g+start.h;
  start.prev := nil;
  
  open:= new List<dot>();
  close:= new List<dot>();
  open.Add(start);
  
  while open.Count<>0 do begin
    var node := choose_node(open, finish);
    
    if (node.x = finish.x) and (node.y = finish.y) then begin
      find_path:= build_path(node);
      exit;
    end;
    
    DeleteFromList(open, node);
    close.Add(node);
    
    new_open:= GetDotNeighbors(node);
    new_open.ForEach(procedure(n) -> 
    begin
      var newg := n.g + nodeWeight(node, n);
      if not ((n.g<=newg) and (IsInList(n, open) or IsInList(n, close))) then
      begin
        n.prev := @node;
        n.g := newg;
        n.h := nodeWeight(n, finish);
        n.f := n.g + n.h;
        if IsInList(n, close) then
          DeleteFromList(close, n);
        if not IsInList(n, open) then
          open.Add(n);
      end;
    end);
    close.Add(node);
  end;
end;

{Расчет направления (то есть нормализация вектора) и умножение его на
скорость юнита}
function directionSpeed(x,y:integer; speed:real):cord;
var v:cord;
begin
  var l := sqrt(sqr(x) + sqr(y));
  if l<>0 then begin
    v.x := round(1/l * x * speed); 
    v.y:=round(1/l * y *speed);
  end
  else begin
    v.x:=0; v.y:=0;
  end;
  directionSpeed := v;
end;

procedure EnemyMove(e:Enemy);
begin
  var e_c := e.GetCrossPoint();
  var t_x := round(target.obj.Position.X / 48);
  var t_y := round(target.obj.Position.Y / 48);
  
  var path := find_path(points[e_c.y,e_c.x],points[t_y,t_x]);
  var t := directionSpeed(path.x*48-e.Pos().x, path.y*48-e.Pos().y, 12.0);
  //writeln(t.x, t.y:3);
  e.MoveOn(t.x, t.y, 12);
end;

{Update - цикл (таймер) обработки игровых событий}
procedure Update();
begin
  EnemyMove(enemy_one);
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
      var r_rect := RectangleABC.Create(0,0, 8, 8, clRed);
      var x:=24+48*(j-1); var y:=24+48*(i-1);   
      r_rect.MoveTo(x-4,y-4);
      if not (r_rect.Intersect(edge_zone)) then begin
        r_rect.Color := clLime;
        points[i,j].x := j; points[i,j].y:=i;
        points[i,j].can_get := true;
      end;
    end;
  end;
  //r_rect.Destroy();
  {=======================================}
  
  {Создаем и располагаем на поле врага и цель}
  enemy_one := new Enemy(120, 240, 24, 48);
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