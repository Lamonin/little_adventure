program path_find_0;

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
begin
  while to_node.prev <> nil do begin
    to_node := to_node.prev^;
    if to_node.prev^.prev = nil then break;
  end;
  
  build_path:= to_node;
end;

function get_best_point(nodes:arr_point; f:path_point):path_point;
var min, weight:integer;
    best_p:path_point;
begin
  min:=9999;
  foreach var s in nodes do begin
    weight := abs(s.x-f.x) + abs(s.y-f.y);
    if weight < min then begin
      min:= weight;
      best_p:=s;
    end;
  end;
  get_best_point:=best_p;
end;

function get_node_children(n:path_point):arr_point;
var temp:arr_point = [];
begin
  foreach var s in n.sosedi do
    if points[s.x, s.y].can_get then Include(temp, points[s.x, s.y]);
  get_node_children:= temp;
end;

function find_path(start_point, f:path_point):path_point;
var all_path:arr_point = [];
    close:arr_point = [];
    cannot:arr_point = [];
    node, temp_p:path_point;
begin
  var childrens := get_node_children(start_point);
  node := get_best_point(childrens, f); node.prev := nil;
  while childrens <> [] do begin
    if not (node in close) then Include(close, node);
    include(all_path, node);
    node := get_best_point(childrens, f);
    
    if (node.x=f.x) and (node.y=f.y) then begin
      foreach var s in all_path do begin
        find_path:=s;
        exit;
      end;
      //find_path:=build_path(node);
      exit;
    end;
    
    childrens := get_node_children(node) - close - cannot;
    while (childrens=[]) and (node.prev<>nil) do begin
      temp_p:=node.prev^;
      Include(cannot, node);
      node:=temp_p;
      Exclude(close, node);
      
      childrens := get_node_children(node) - close - cannot;
    end;
  end;
end;

function directionSpeed(x,y:integer; speed:real):dot;
var v:dot;
begin
  var l := sqrt(sqr(x) + sqr(y));
  v.x := round((1/l * x)*speed); v.y:=round((1/l * y)*speed);
  directionSpeed := v;
end;
    
procedure EnemyMove(var e:moving_object);
var v, p:dot;
begin
  p.x:=enemy.obj.Position.X div 48; p.y:=enemy.obj.Position.Y div 48;
  var path:= find_path(points[p.x, p.y], points[target.cross_point.x, target.cross_point.y]);
  
  v := directionSpeed(path.x-p.x, path.y-p.y, 4.0);
  enemy.obj.MoveOn(v.x, v.y);
end;

begin
  death_zone := PictureABC.Create(0,0, 'obstacle_ver_2.png');
  {Инициализация сетки возможных путей на уровне}
  Window.Width := 1248;
  Window.Height := 768;
  SetWindowIsFixedSize(true);
  SetWindowTitle('Тест поиска пути объектов. Версия 1.0');
  for var i:=1 to Window.Width div 24 do
    if i mod 2 = 1 then
      world_x_p+=1;
  for var i:=1 to Window.Height div 24 do
    if i mod 2 = 1 then
      world_y_p+=1;
  
  points:= new path_point[world_x_p,world_y_p];
  
  
  for var i:=1 to world_x_p-1 do begin
    for var j:=1 to world_y_p-1 do begin
      var r_rect := RectangleABC.Create(0,0,8,8, clRed);
      var x:= 48*i;
      var y:= 48*j;
      points[i,j].can_get := false;
      r_rect.MoveTo(x-4,y-4);
      if not r_rect.Intersect(death_zone) then begin
        r_rect.Color := clGreen;
        points[i,j].can_get := true;
        points[i,j].x:=i; points[i,j].y:=j;
      end;
    end;
  end;
  //r_rect.Destroy();
  
  for var i:=0 to world_x_p-2 do
    for var j:=0 to world_y_p-2 do begin
      if points[i,j].can_get then begin
        var t:dot; t.x:=i; t.y:=j+1;
        if points[i,j+1].can_get then begin
          Include(points[i,j].sosedi, t);
          t.x:=i; t.y:=j;
          Include(points[i,j+1].sosedi, t);
        end;
        if (i>0) and points[i+1,j].can_get then begin
          t.x:=i+1; t.y:=j;
          Include(points[i,j].sosedi, t);
          t.x:=i; t.y:=j;
          Include(points[i+1,j].sosedi, t);
        end;
      end;
    end;

  
 {****************************************}
  
  enemy.x:=142;
  enemy.y:=200;
  enemy.obj:=RectangleABC.Create(enemy.x, enemy.y, 24, 48, clRed);
  
  target.x:=142;
  target.y:=574;
  target.obj:=RectangleABC.Create(target.x, target.y, 24, 24, clBlack);
  
  target.cross_point.x := target.x div 48;
  target.cross_point.y := target.y div 48;
  
  while(true) do begin
    EnemyMove(enemy);
    
    Sleep(16);
  end;
end.