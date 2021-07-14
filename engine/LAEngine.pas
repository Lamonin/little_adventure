unit LAEngine;
interface
uses GraphWPF, WPFObjects, Timers;
type
  spriteInfo=record
    frames:array of string; //Кадры анимации
    speed:integer; //Скорость анимации
    isLoop:boolean; //Зациклена ли анимация
    end;
  LSprite = class
    private
    anims:Dictionary<string, spriteInfo>; //Все анимации по их именам
    defaultAnim:string; //Имя стандартной анимации
    curAnim:spriteInfo; //Текущая анимация
    sprite:PictureWPF;
    
    updater:Timer;
    frameNum:Integer; //Номер текущего кадра анимации
    
    procedure ChangeSprite();
    begin
      var t := sprite;
      sprite:= new PictureWPF(t.LeftTop, curAnim.frames[frameNum]);
      t.Destroy();
    end;
    
    //Обновление кадра изображения
    procedure UpdateFrame();
    begin
      if (frameNum<curAnim.frames.Length) then begin
        ChangeSprite();
        frameNum+=1;
      end
      else begin
        if not (curAnim.isLoop) then
          PlayAnim(defaultAnim)
        else
          frameNum:=0;
      end;
    end;
    
    public
    ///Конструктор с инициализацией стандартной анимации с обычными параметрами
    constructor Create(x,y:integer; aname:string; frames:array of string);
    begin
      anims := new Dictionary<string, spriteInfo>();
      defaultAnim:=aname;
      AddAnim(aname, frames, 160, True); //Обычно анимация зациклена
      sprite := new PictureWPF(x,y,anims[defaultAnim].frames[0]);
    end;
    
    ///Конструктор с инициализацией стандартной анимации
    constructor Create(x,y:integer; aname:string; frames:array of string; speed:integer; looped:boolean);
    begin
      anims := new Dictionary<string, spriteInfo>();
      defaultAnim:=aname;
      AddAnim(aname, frames, speed, looped);
      sprite := new PictureWPF(x,y,anims[defaultAnim].frames[0]);
    end;
    
    ///Добавляет новую анимацию с именем aname
    procedure AddAnim(aname:string; frames:array of string; speed:integer; looped:boolean);
    begin
      var frame:spriteInfo;
      frame.frames:= frames; frame.speed:=speed; frame.isLoop:=looped;
      anims.Add(aname, frame);
    end;
    
    procedure PlayAnim(aname:string);
    begin
      curAnim := anims[aname];
      if (updater <> nil) then updater.Stop();
      frameNum := 0;
      if (curAnim.frames.Length=1) then begin
        ChangeSprite();
      end
      else begin
        updater := new Timer(curAnim.speed, UpdateFrame);
        updater.Start();
      end;
    end;
  end;
  
  ///Загружает последовательность спрайтов с именем sname и номерами от 0 до count
  function LoadSprites(sname:string; count:integer):array of string;
  
implementation
function LoadSprites(sname:string; count:integer):array of string;
begin
  Result := new string[count];
  for var i:= 0 to count-1 do begin
    Result[i] := 'img/'+sname+(i+1)+'.png';
  end;
end;
end.