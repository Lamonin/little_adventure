uses WPFObjects;
uses LAEngine in 'engine/LAEngine.pas';

//Обработка ввода пользователя
procedure KeyDown(k: Key);
begin
  ///Если возможно, то скрываем изображение перехода
  if (LAGD.TransPic.CanHide) and (k = Key.Space) then LAGD.TransPic.Hide();
  if (LAGD.Player = nil) or (LAGD.Player.isBlocked) then exit;
  if (k = key.E) then LAGD.Player.UseGrid();
  if (k = Key.W) or (k = key.Up) then
    LAGD.Player.MoveOn(0, -1, 'up')
  else if (k = Key.S) or (k = key.Down) then
    LAGD.Player.MoveOn(0, 1, 'down')
  else if (k = Key.A) or (k = key.Left) then
    LAGD.Player.MoveOn(-1, 0, 'left')
  else if (k = Key.D) or (k = key.Right) then
    LAGD.Player.MoveOn(1, 0, 'right');
end;

begin
  StartGame();
  OnKeyDown := KeyDown;
end.