program summer_practice;
uses GraphWPF, WPFObjects;
uses LAEngine in 'engine/LAEngine.pas';

//Процедура вызывается каждый раз при отрисовке
procedure OnDraw(dt:real);
begin
  LAGD.TransPic.ToFront();
end;

//Обработка ввода пользователя
procedure KeyDown(k: Key);
begin
  if (LAGD.TransPic.CanHide) and (k = Key.Space) then LAGD.TransPic.Hide();
  if (LAGD.Player = nil) or (LAGD.Player.isBlocked) then exit;
  if (k = key.E) then begin
    var l := LAGD.Grid[LAGD.Player.GetY, LAGD.Player.GetX].GridObject;
    if (l<>nil) and (l.objType = 'nextLevel') then begin
      ChangeLevel(l.NextLevelName);
      exit;
    end;
    LAGD.Player.UseGrid();
  end;
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
  Window.Caption := 'Little Adventure';
  Window.IsFixedSize := True;
  Window.SetSize(1296, 768);
  Window.CenterOnScreen();
  
  LAGD.TransPic := new TransitionPic();
  ///Загружаем "прогресс" игрока
  var loader := new LALoader('data/userdata.json');
  ChangeLevel(loader.GetValue&<string>('$.current_level'));
  //LoadLevel(loader.GetValue&<string>('$.current_level'));
  
  OnDrawFrame += OnDraw;
  OnKeyDown := KeyDown;
end.