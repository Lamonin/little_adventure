{Модуль содержит основные переменные игры и функции}
{$reference Vector2.dll}
unit LAEngine;
uses GraphABC, ABCObjects, Timers;

type
  MsgType = (Attention, Dialog, Question);

  Entity = class
    private
    position : V2 = new V2();
    w,h:integer;
    speed:integer;
    hitpoint:integer;
    msgABC:record
      obj:MultiPictureABC;
      taskTimer:Timer;
      hasShowed:boolean;
      timerTick, msgImageCount:integer;
    end;
    
    //Устанавливает позицию Mover и смещает графическое представление
    //по целочисленным координатам
    procedure setPos(v:V2);
    begin
      position := v;
      obj.MoveTo(round(position.x - w div 2), round(position.y-h div 2));
      if not (msgABC.obj = nil) then
        msgABC.obj.MoveTo(position.x-w div 2 - 20, position.y-h div 2 - 32);
    end;
    
    //Возвращает позицию Mover
    function getPos():V2;
    begin
      Result := position;
    end;
    
    public
    obj:ObjectABC;
    
    constructor Create(x, y, wt, ht, hp, spd:integer);
    begin
      w:=wt; h:=ht; hitpoint:=hp; speed:=spd;
      position.x := x; position.y:=y;
    end;
    
    procedure ShowMessage(duration:integer; messageType:MsgType);
    var path:string;
    
    begin
      if (messageType = MsgType.Dialog) then begin
        path := 'img\bubble_emote_0.png';
      end
      else if (messageType = MsgType.Attention) then begin
        path := 'img\bubble_emote_1.png';
      end
      else if (messageType = MsgType.Question) then begin
        path := 'img\bubble_emote_2.png';
      end;
      
      if not (msgABC.obj = nil) then begin
        msgABC.obj.Destroy();
        msgABC.taskTimer.Stop();
      end;
      
      msgABC.obj := MultiPictureABC.Create(position.x-w div 2 - 20, position.y-h div 2 - 32, 32, 'img\bubble_start.png');
      msgABC.timerTick := 0; msgABC.msgImageCount := msgABC.obj.Count;
      
      msgABC.taskTimer := new Timer(64, procedure() -> begin
        if (msgABC.timerTick>=duration) then begin
          if msgABC.hasShowed then begin
            msgABC.hasShowed := false;
            msgABC.obj.ChangePicture(32, 'img\bubble_start.png');
            msgABC.obj.CurrentPicture := msgABC.msgImageCount;
          end;
          if (msgABC.obj.CurrentPicture > 1) then
            msgABC.obj.PrevPicture()
          else begin
            msgABC.obj.Destroy(); msgABC.obj:=nil;
            msgABC.taskTimer.Stop();
          end;
        end
        else begin
          msgABC.timerTick += 64;
          if (msgABC.obj.CurrentPicture < msgABC.msgImageCount) then begin
            duration -= 64;
            msgABC.obj.NextPicture();
          end
          else if not msgABC.hasShowed then begin
            msgABC.hasShowed := true;
            msgABC.obj.ChangePicture(path);
          end;
        end;
      end);
      
      msgABC.taskTimer.Start();
    end;
    
    procedure MoveOn(v:V2);
    begin
      
    end;
    
    property pos:V2 read getPos write setPos;
  end;
  
  Player = class(Entity)
    private
    
    public
    constructor Create(x,y,w,h, hp, speed:integer; pathToSprite:string);
    begin
      inherited Create(x, y, w, h, hp, speed);
      obj := RectangleABC.Create(x - w div 2, y-h div 2, w, h, clRed);
    end;
    
  end;
  
  //Класс объекта для взаимодействия с ним
  Prop = class
    private
    positon : V2 := new V2();
    
    public
    obj : ObjectABC;
    
    constructor Create();
    begin
      
    end;
  end;
end.