program summer_practice;
uses GraphWPF, WPFObjects;
uses LAEngine in 'engine/LAEngine.pas';

var player:PlayerWorld;

//Процедура вызывается каждый раз при отрисовке
procedure OnDraw(dt:real);
begin
end;

//Обработка ввода пользователя
procedure KeyDown(k: Key);
begin
  if (k = Key.W) or (k = key.Up) then
    player.MoveOn(player.GetX,player.GetY-1, 'up')
  else if (k = Key.S) or (k = key.Down) then
    player.MoveOn(player.GetX,player.GetY+1, 'down')
  else if (k = Key.A) or (k = key.Left) then
    player.MoveOn(player.GetX-1,player.GetY, 'left')
  else if (k = Key.D) or (k = key.Right) then
    player.MoveOn(player.GetX+1,player.GetY, 'right')
end;

begin
  
  player := new PlayerWorld(0, 0);
  
  OnDrawFrame += OnDraw;
  OnKeyDown := KeyDown;
end.