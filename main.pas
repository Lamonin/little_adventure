uses WPFObjects;
uses LAEngine in 'engine/LAEngine.pas';

//Обработка ввода пользователя
procedure KeyDown(k: Key);
begin
  ///Если возможно, то скрываем изображение перехода
  if (Player = nil) or (Player.isBlocked) then exit;
  if (k = key.E) then begin
    if (DialogHandler.NextMessage) then exit;
    Player.UseGrid();
  end;
  if DialogHandler.isInDialogue then exit; //Если разговариваем
  if (k = Key.W) or (k = key.Up) then Player.MoveOn(0, -1, 'up')
  else if (k = Key.A) or (k = key.Left) then Player.MoveOn(-1, 0, 'left')
  else if (k = Key.S) or (k = key.Down) then Player.MoveOn(0, 1, 'down')
  else if (k = Key.D) or (k = key.Right) then Player.MoveOn(1, 0, 'right');
end;

begin
  StartGame();
  OnKeyDown := KeyDown;
end.