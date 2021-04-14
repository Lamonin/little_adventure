﻿program path_find_0;

uses GraphABC, ABCObjects;
type 
p_path = ^path_point;

dot = record x:integer; y:integer; end;
arr_dots = set of dot;
path_point = record x:integer; y:integer; prev:p_path; can_get:boolean; sosedi:arr_dots end;
arr_point = set of path_point;

moving_object = record
  obj:RectangleABC;
  x:integer;
  y:integer;
  cross_point:path_point;
end;

var enemy, target:moving_object; death_zone:ObjectABC;
    world_x_p, world_y_p:integer;
    points: array [,] of path_point;
    
function build_path (to_node:path_point): path_point;
var p:path_point;
begin
  while to_node.prev^.prev <> nil do begin
    //writeln(to_node.prev^);
    p:=to_node.prev^;
    writeln(p, ' ', to_node);
    to_node:=points[p.x,p.y];
  end;
  writeln(to_node.x, ' ', to_node.y);
  build_path:= to_node;
end;

function get_best_point(nodes:List<path_point>; f:path_point):path_point;
var min, weight:integer;
    best_p:path_point;
begin
  min:=9999;
  
  for var i:=0 to nodes.Count-1 do begin
    var s:=nodes[i];
    weight := abs(s.x-f.x) + abs(s.y-f.y);
    if weight < min then begin
      min:= weight;
      best_p:=s;
    end;
  end;
  get_best_point:=points[best_p.x, best_p.y];
end;

function get_node_children(n:path_point):List<path_point>;
var temp:List<path_point>;
begin
  temp:= new List<path_point>();
  foreach var s in n.sosedi do begin 
  if points[s.x, s.y].can_get then
    temp.Add(points[s.x, s.y]);
  end;
  get_node_children:= temp;
end;

procedure RemoveListElemements(var std:List<path_point>; minus:List<path_point>);
begin
  for var j:=0 to minus.Count-1 do
    for var i:=0 to std.Count-1 do
      if std[i] = minus[j] then begin
        std.RemoveAt(i); break; 
      end;
end;

procedure RemoveListElem(var std:List<path_point>; elem:path_point);
begin
  for var i:= 0 to std.Count-1 do
    if std[i]=elem then begin
      std.RemoveAt(i);
      exit;
    end;
end;

function ListContains(list_t:List<path_point>; elem:path_point):boolean;
begin
  for var i:=0 to list_t.Count-1 do
    if list_t[i]=elem then begin
      ListContains:=true;
      exit;
    end;
  ListContains:=false;
end;

function find_path(start_point, f:path_point):path_point;
var reachable, explored, new_reachable : List<path_point>;

begin
  writeln('START IS ',start_point, ' ', f); 
  reachable:= new List<path_point>();
  explored:= new List<path_point>();
  new_reachable:= new List<path_point>();
  
  reachable.Add(start_point);
  while reachable.Count <> 0 do begin
    var node := get_best_point(reachable, f);
    if (points[node.x, node.y].x=f.x) and (points[node.x, node.y].y=f.y) then begin
      find_path:=build_path(points[node.x, node.y]);
      exit;
    end;
    
    RemoveListElem(reachable, points[node.x, node.y]);
    
    explored.Add(points[node.x, node.y]);
    new_reachable:= get_node_children(points[node.x, node.y]);
    RemoveListElemements(new_reachable, explored);
    
    for var i:= 0 to new_reachable.Count-1 do begin
      var s:= new_reachable[i];
      if not ListContains(reachable, s) then begin
        points[s.x,s.y].prev:= @points[node.x, node.y];
        reachable.Add(points[s.x,s.y]);
      end;
    end;
  end;
  //find_path:=start_point;
end;

{Расчет направления (то есть нормализация вектора) и умножение его на
скорость юнита}
function directionSpeed(x,y:integer; speed:real):dot;
var v:dot;
begin
  var l := sqrt(sqr(x) + sqr(y));
  if l<>0 then begin
    v.x := round(1/l * x*speed); v.y:=round(1/l * y *speed);
  end
  else begin
    v.x:=0; v.y:=0;
  end;
  writeln(v.x, v.y);
  directionSpeed := v;
end;
    
procedure EnemyMove(var e:moving_object);
var v, p:dot;
begin
  p.x:=(enemy.obj.Position.X-24) div 48; p.y:=(enemy.obj.Position.Y-24) div 48;
  writeln(p.x, ' ', p.y);
  var path:= find_path(points[p.y,p.x], points[target.cross_point.y, target.cross_point.x]);
  v := directionSpeed(path.x-p.x, path.y-p.y, 4.0);
  enemy.obj.MoveOn(v.x, v.y);
end;

begin
  SetConsoleIO();
  Window.Width := 1248;
  Window.Height := 768;
  SetWindowIsFixedSize(true);
  SetWindowTitle('Тест поиска пути объектов. Версия 1.0');
  
  death_zone := PictureABC.Create(0,0, 'obstacle_ver_2.png');
  {Инициализация сетки возможных путей на уровне}
  for var i:=1 to Window.Width div 24 do
    if i mod 2 = 1 then
      world_x_p+=1;
  for var i:=1 to Window.Height div 24 do
    if i mod 2 = 1 then
      world_y_p+=1;
  
  points:= new path_point[world_y_p,world_x_p];
  
  
  for var i:=1 to world_y_p-1 do begin
    for var j:=1 to world_x_p-1 do begin
      var r_rect := RectangleABC.Create(0,0,8,8, clRed);
      var x:= 48*j;
      var y:= 48*i;
      points[i,j].prev:=nil;
      r_rect.MoveTo(x-4,y-4);
      if not r_rect.Intersect(death_zone) then begin
        r_rect.Color := clGreen;
        points[i,j].can_get := true;
        points[i,j].x:=i; points[i,j].y:=j;
      end;
    end;
  end;
  //r_rect.Destroy();
  
  for var i:=0 to world_y_p-2 do
    for var j:=0 to world_x_p-2 do begin
      if points[i,j].can_get then begin
        var t:dot; t.x:=i; t.y:=j+1;
        if points[i,j+1].can_get then begin
          Include(points[i,j].sosedi, t);
          t.x:=i; t.y:=j;
          Include(points[i,j+1].sosedi, t);
        end;
        if points[i+1,j].can_get then begin
          t.x:=i+1; t.y:=j;
          Include(points[i,j].sosedi, t);
          t.x:=i; t.y:=j;
          Include(points[i+1,j].sosedi, t);
        end;
      end;
    end;
  
//  for var i:=0 to world_y_p-1 do begin
//    for var j:=0 to world_x_p-1 do write(points[i,j].can_get, ' ');
//    writeln();
//  end;
  
 {****************************************}
  
  enemy.x:=142;
  enemy.y:=200;
  enemy.obj:=RectangleABC.Create(enemy.x, enemy.y, 24, 48, clRed);
  
  target.x:=142;
  target.y:=574;
  target.obj:=RectangleABC.Create(target.x, target.y, 24, 24, clBlack);
  
  target.cross_point.x := (target.x-24) div 48;
  target.cross_point.y := (target.y-24) div 48;
  
  while(true) do begin
    EnemyMove(enemy);
    
    Sleep(16);
  end;
end.