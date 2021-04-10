{Тест движения игрока и камеры}
program move_camera_player;

uses GraphABC, ABCObjects, ABCSprites, Timers;

type
  xycor = record x: integer; y: integer end;
  velocity = record x: integer; y: integer end;
  static_entity = record 
                    obj: PictureABC; 
                    x: integer;
                    y: integer;
                end;
  check_coll_lines = record
                        left: EllipseABC;
                        right: EllipseABC;
                        up: EllipseABC;
                        down: EllipseABC;
                     end;
  dyn_entity = record 
                  obj: SpriteABC; 
                  x: integer; 
                  y: integer; 
                  speed:integer; 
                  vel: velocity;
                  col_lines : check_coll_lines;
               end;
var
  cam_cor: xycor; bg, enemy, lock_zone: static_entity; player: dyn_entity;
  mirror: boolean;

procedure KeyDown(Key: integer);
begin
  if (Key = VK_Left) or (Key = VK_Right) or (Key = VK_Up) or (Key = VK_Down) then
    player.obj.State := 2;
  case Key of
    VK_Left:
      begin
        player.vel.x := 1;
        if not mirror then begin
          player.obj.FlipHorizontal();
          mirror := true;
        end;
      end;
    VK_Right:
      begin
        player.vel.x := -1;
        if mirror then begin
          player.obj.FlipHorizontal();
          mirror := false;
        end;
      end;
    VK_Up:    player.vel.y := 1;
    VK_Down:  player.vel.y := -1;
  end;
end;

procedure KeyUp(Key: integer);
begin
  if (Key = VK_Left) or (Key = VK_Right) or (Key = VK_Up) or (Key = VK_Down) then
    player.obj.State := 1;
  if (Key = VK_Left) or (Key = VK_Right) then player.vel.x := 0;
  if (Key = VK_Up) or (Key = VK_Down) then player.vel.y := 0;
end;

procedure CreateCheckLines(var a:dyn_entity);
var x,y,w,h:integer;
begin
  x:= a.obj.Position.X;
  y:= a.obj.Position.Y;
  w:= a.obj.Width;
  h:= a.obj.Height;
  a.col_lines.left := EllipseABC.Create(0+w div 2,0, w div 2, h);
  ToBack(a.col_lines.left);
  a.col_lines.right := EllipseABC.Create(w - w div 2,0, w div 2, h div 2);
  ToBack(a.col_lines.right);
  a.col_lines.up := EllipseABC.Create(0,0, w div 2, h div 2);
  ToBack(a.col_lines.up);
  a.col_lines.down := EllipseABC.Create(0,h-h div 2, w div 2, h div 2);
  ToBack(a.col_lines.down);
end;

procedure MoveCheckLines(var a:dyn_entity);
var w,h:integer;
begin
  w:= a.obj.Width;
  h:= a.obj.Height;
  
  a.col_lines.left.MoveTo(a.x, a.y + h div 4);
  a.col_lines.right.MoveTo(a.x + w - w div 2, a.y + h div 4);
  a.col_lines.up.MoveTo(a.x, a.y);
  a.col_lines.down.MoveTo(a.x, a.y + h-h div 2);
end;

procedure MoveCam();
begin
  
  if (player.vel.x > 0) and not player.col_lines.left.Intersect(lock_zone.obj) then
    cam_cor.x := cam_cor.x + player.vel.x * player.speed
  else if (player.vel.x < 0) and not player.col_lines.right.Intersect(lock_zone.obj) then
    cam_cor.x := cam_cor.x + player.vel.x * player.speed;
  
  if (player.vel.y > 0) and not player.col_lines.up.Intersect(lock_zone.obj) then
    cam_cor.y := cam_cor.y + player.vel.y * player.speed
  else if (player.vel.y < 0) and not player.col_lines.down.Intersect(lock_zone.obj) then
    cam_cor.y := cam_cor.y + player.vel.y * player.speed;
  
  MoveCheckLines(player);
end;

procedure RedrawWorld();
begin
  bg.obj.MoveTo(cam_cor.x + bg.x, cam_cor.y + bg.y);
  lock_zone.obj.MoveTo(cam_cor.x + lock_zone.x, cam_cor.y + lock_zone.y);
  enemy.obj.MoveTo(cam_cor.x + 640-96, cam_cor.y + 360);
  //RedrawObjects();
end;

procedure GameCycle();
begin
   MoveCam();
   RedrawWorld();
   //RedrawObjects();
   Sleep(16);
end;

procedure GameCycle1();
begin
  RedrawWorld();
end;

begin
  Window.Width := 1280;
  Window.Height := 720;
  Window.IsFixedSize := true;
  Window.CenterOnScreen();
    
  OnKeyDown := KeyDown;
  OnKeyUp := KeyUp;
  
  player.x := Window.Width div 2;
  player.y := Window.Height div 2 - 96;
  
  mirror := false;
  
  bg.obj := PictureABC.Create(0, 0, 'level.png');
  lock_zone.obj := PictureABC.Create(0, 0, 'lock.png');
  
  player.obj := SpriteABC.Create(player.x, player.y, 64, 'elf_anim.png');
  player.speed := 12;
  CreateCheckLines(player);
  
  enemy.obj := PictureABC.Create(640, 360, 'elf.png');
  enemy.obj.Scale(3);
  
  player.obj.AddState('idle', 4);
  player.obj.AddState('run', 4);
  player.obj.AddState('hit', 1);
  player.obj.AddState('except', 9); //"лишние" кадры
  player.obj.CheckStates(); //Обязательно нужно вызвать
  player.obj.Speed := 9;
  
  StartSprites();
  
  //Использование таймера почему-то помогает избавиться от проблем
  //LockDrawingObjects();
  //var cycle1 := new Timer(16, RedrawWorld);
  //cycle1.Start();
  
  var cycle := new Timer(16, GameCycle);
  cycle.Start();
  

//  while (true) do
//  begin
//
//  end;
end.