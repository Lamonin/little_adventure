{Тест движения игрока и камеры}
program move_camera_player;

uses GraphABC, ABCObjects, ABCSprites, Timers;

type
  xycor = record x: integer; y: integer end;
  velocity = record x: integer; y: integer end;
  static_entity = record obj: PictureABC; x: integer; y: integer; end;
  
  dyn_entity = record 
                  obj: SpriteABC; 
                  x: integer; 
                  y: integer; 
                  speed:integer; 
                  vel: velocity 
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

function plIntersect():boolean;
begin
  if ObjectUnderPoint(cam_cor.x + player.x - 32, cam_cor.y + player.y) = lock_zone.obj then
    plIntersect := true
  else if ObjectUnderPoint(cam_cor.x + player.x + 32, cam_cor.y + player.y) = lock_zone.obj then
    plIntersect := true
  else if ObjectUnderPoint(cam_cor.x + player.x , cam_cor.y + player.y + 32) = lock_zone.obj then
    plIntersect := true
  else if ObjectUnderPoint(cam_cor.x + player.x, cam_cor.y + player.y - 32) = lock_zone.obj then
    plIntersect := true
  else plIntersect := false;
end;

procedure MoveCam();
begin
  if plIntersect() then writeln('FUCK');
  
  if (cam_cor.x + player.vel.x * player.speed + player.x) < 640 then
    cam_cor.x := cam_cor.x + player.vel.x * player.speed
  else begin
    player.x := player.x - player.vel.x * player.speed;
    player.obj.MoveTo(player.x, player.y);
  end;
  cam_cor.y := cam_cor.y + player.vel.y * player.speed;
  
end;

procedure RedrawWorld();
begin
  bg.obj.MoveTo(cam_cor.x + bg.x, cam_cor.y + bg.y);
  lock_zone.obj.MoveTo(cam_cor.x + lock_zone.x, cam_cor.y + lock_zone.y);
  enemy.obj.MoveTo(cam_cor.x + 640-96, cam_cor.y + 360);
end;

procedure GameCycle();
begin
   RedrawWorld();
   MoveCam();
   RedrawObjects();
   Sleep(16);
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
  enemy.obj := PictureABC.Create(640, 360, 'elf.png');
  enemy.obj.Scale(4);
  
  player.obj.AddState('idle', 4);
  player.obj.AddState('run', 4);
  player.obj.AddState('hit', 1);
  player.obj.AddState('except', 9); //"лишние" кадры
  player.obj.CheckStates(); //Обязательно нужно вызвать
  player.obj.Speed := 9;
  
  StartSprites();
  
  //Использование таймера почему-то помогает избавиться от проблем
  LockDrawingObjects();
  var cycle := new Timer(24, GameCycle);
  cycle.Start();

//  while (true) do
//  begin
//
//  end;
end.