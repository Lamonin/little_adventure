uses WPFObjects;
uses LAEngine in 'engine/LAEngine.pas';

//Обработка ввода пользователя
procedure KeyDown(k: Key);
begin
  ///Если возможно, то скрываем изображение перехода
  if (GD.TransPic.CanHide) and (k = Key.Space) then GD.TransPic.Hide();
  if (GD.Player = nil) or (GD.Player.isBlocked) then exit;
  if (k = key.E) then begin
    if (GD.DialogHandler<>nil) and (GD.DialogHandler.NextMessage) then exit;
    GD.Player.UseGrid();
  end;
  if (k = Key.W) or (k = key.Up) then GD.Player.MoveOn(0, -1, 'up')
  else if (k = Key.A) or (k = key.Left) then GD.Player.MoveOn(-1, 0, 'left')
  else if (k = Key.S) or (k = key.Down) then GD.Player.MoveOn(0, 1, 'down')
  else if (k = Key.D) or (k = key.Right) then GD.Player.MoveOn(1, 0, 'right');
end;

begin
  StartGame();
  OnKeyDown := KeyDown;
end.