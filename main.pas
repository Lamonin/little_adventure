program summer_practice;
uses GraphWPF, WPFObjects;
uses LAEngine in 'engine/LAEngine.pas';

var gData:gameInfo;

//Процедура вызывается каждый раз при отрисовке
procedure OnDraw(dt:real);
begin
  gData.transPic.ToFront();
end;

//Обработка ввода пользователя
procedure KeyDown(k: Key);
begin
  if (gData.transPic.CanHide) and (k = Key.Space) then gData.transPic.Hide(gData.player);
  if (gData.player = nil) or (gData.player.isBlocked) then exit;
  if (k = key.E) then begin
    var l := gData.levelGrid[gData.player.GetY,gData.player.GetX].GridObject;
    if (l<>nil) and (l.objType = 'nextLevel') then begin
      ChangeLevel(gData, l.NextLevelName);
      exit;
    end;
    gData.player.UseGrid(gData.levelGrid);
  end;
  if (k = Key.W) or (k = key.Up) then
    gData.player.MoveOn(0, -1, 'up', gData.levelGrid)
  else if (k = Key.S) or (k = key.Down) then
    gData.player.MoveOn(0, 1, 'down', gData.levelGrid)
  else if (k = Key.A) or (k = key.Left) then
    gData.player.MoveOn(-1, 0, 'left', gData.levelGrid)
  else if (k = Key.D) or (k = key.Right) then
    gData.player.MoveOn(1, 0, 'right', gData.levelGrid)
end;

begin
  PrepareWindow();
  gData.transPic := new TransitionPic();
  var loader := new LALoader('data/userdata.json');
  LoadLevel(gData, loader.GetValue&<string>('$.current_level'));
  //player := new PlayerWorld(8, 4);

  OnDrawFrame += OnDraw;
  OnKeyDown := KeyDown;
end.