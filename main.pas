program summer_practice;
uses GraphWPF, WPFObjects;
uses LAEngine in 'engine/LAEngine.pas';

procedure OnDraw(dt:real);
begin
end;

procedure KeyDown(k: Key);
begin
end;

begin
  var p := new LSprite(100, 100, 'idle', LoadSprites('pig_idle_', 11), 100, true);
  p.PlayAnim('idle');
  
  OnDrawFrame := OnDraw;
  OnKeyDown := KeyDown;
//  while (true) do begin
//    Redraw(procedure()-> 
//    begin
//       
//    end);
//  end;
end.