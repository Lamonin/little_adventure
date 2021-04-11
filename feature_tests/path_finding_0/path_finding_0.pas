program path_find_0;

uses GraphABC, ABCObjects;
type 
p_path = ^path_point;
path_point = record x:integer; y:integer; prev:p_path; end;
arr_point = set of path_point;
moving_object = record
  obj:RectangleABC;
  x:integer;
  y:integer;
  cross_point:path_point;
end;

var enemy, target:moving_object; death_zone:ObjectABC;
    world_x_p, world_y_p:integer;
    points: array [,] of boolean;
    
function build_path (to_node:path_point): path_point;
begin
  while to_node.prev <> nil do
      to_node := to_node.prev^;
  build_path:= to_node;
end;

function return_weight(one, two:path_point):integer;
begin
  return_weight:= abs(one.x-two.x)+abs(one.y-two.y);
end;

function choose_node(reachable:arr_point; end_p:path_point):path_point;
var best:path_point;
begin
  var min := 99999;
  foreach var s in reachable do begin
    var weight:= return_weight(s, end_p);
    if weight<min then begin
      min:=weight;
      best:=s;
    end; end;
  choose_node := best;
end;

function get_sosednie(p:path_point):arr_point;
var x,y:integer;
    sosednie:arr_point = [];
begin
  x:=p.x;
  y:=p.y;
  for var i:=-1 to 1 do begin
    if i=0 then
      for var j:=-1 to 1 do
        if (j<>0) and ((y+j>=0) and (y+j<=world_y_p)) and points[x, y+j] then begin
          var t:path_point;
          t.x := x; t.y:=y+j;
          Include(sosednie, t);
        end
    else
      if ((x+i>=0) and (x+i<=world_x_p)) and points[x+i, y] then begin
        var t:path_point;
        t.x := x+i; t.y:=y;
        Include(sosednie, t);
      end;
  end;
  get_sosednie := sosednie;
end;

function find_path(start_point, end_point:path_point):path_point;
var open:arr_point = [start_point];
    close:arr_point = [];
begin
  while open<>[] do begin
    var node := choose_node(open,end_point);
    
    if (node.x = end_point.x) and (node.y = end_point.y) then begin
      find_path:=build_path(node);
      exit;
    end;
    
    Exclude(open, node);
    Include(close, node);
    
    var new_open := get_sosednie(node) - close;
    foreach var s in new_open do
      if not (s in open) then begin
        new(s.prev);
        s.prev^ := node;
        Include(open, s);
      end;
  end;
end;
    
procedure EnemyMove(var e:moving_object);
begin
  enemy.cross_point.x := enemy.x div 48;
  enemy.cross_point.y := enemy.y div 48;
  var path:= find_path(enemy.cross_point, target.cross_point);
  writeln(path.x, path.y);
  enemy.obj.MoveTo(path.x*48, path.y*48);
end;

begin
  death_zone := PictureABC.Create(-48,180, 'obstacle.png');
  {Инициализация сетки возможных путей на уровне}


  for var i:=1 to Window.Width div 24 do
    if i mod 2 = 1 then
      world_x_p+=1;
  for var i:=1 to Window.Height div 24 do
    if i mod 2 = 1 then
      world_y_p+=1;
  
  points:= new boolean[world_x_p, world_y_p];
  
  var r_rect := RectangleABC.Create(0,0,16,16, clBlack);
  for var i:=0 to world_x_p-1 do begin
    for var j:=0 to world_y_p-1 do begin
      var x:= 48*i-32;
      var y:= 48*j-32;
      r_rect.MoveTo(x,y);
      if not r_rect.Intersect(death_zone) then
        points[i,j] := true;
    end;
  end;
  r_rect.Destroy();
  {****************************************}
  
  enemy.x:=100;
  enemy.y:=200;
  enemy.obj:=RectangleABC.Create(enemy.x, enemy.y, 20, 80, clRed);
  
  target.x:=400;
  target.y:=300;
  target.obj:=RectangleABC.Create(target.x, target.y, 20, 20, clBlack);
  
  while(true) do begin
    target.cross_point.x := target.x div 48;
    target.cross_point.y := target.y div 48;
    
    EnemyMove(enemy);
    
    Sleep(16);
  end;
end.