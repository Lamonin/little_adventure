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
      if (frameNum<curAnim.frames.Length) then
        frameNum+=1
      else
        if not (curAnim.isLoop) then begin
          PlayAnim(defaultAnim);
          exit;
        end
        else
          frameNum:=0;
      ChangeSprite();
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
  
  ///Загружает спрайт с именем sname.
  function LoadSprites(sname:string):array of string;
  ///Загружает последовательность спрайтов с именем sname и номерами от 0 до count.
  function LoadSprites(sname:string; count:integer):array of string;
  
  ///Класс игрока в "мире".
  PlayerWorld = class
    private
    sprite:LSprite;
    public
    constructor Create(x,y:integer);
    begin
      //Инициализация изображений
      sprite := new LSprite(100, 100, 'idledown', LoadSprites('player/down2'), 100, false);
      sprite.AddAnim('walkleft', LoadSprites('player/left', 4), 160, true);
      sprite.AddAnim('walkright', LoadSprites('player/right', 4), 160, true);
      sprite.AddAnim('walkup', LoadSprites('player/up', 4), 160, true);
      sprite.AddAnim('walkdown', LoadSprites('player/down', 4), 160, true);
      
      sprite.PlayAnim('idledown');
      //*************************
    end;
    
    procedure Finalize(); override;
    begin
      
    end;
  end;
  
  
  
implementation
function LoadSprites(sname:string):array of string;
begin
  Result := new string[1];
  Result[0] := 'img/'+sname+'.png';
end;

function LoadSprites(sname:string; count:integer):array of string;
begin
  Result := new string[count];
  for var i:= 0 to count-1 do begin
    Result[i] := 'img/'+sname+(i+1)+'.png';
  end;
end;
end.