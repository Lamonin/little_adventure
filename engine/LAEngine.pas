unit LAEngine;
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
    curAnimName:string;
    curAnim:spriteInfo; //Текущая анимация
    sprite, tsprite:PictureWPF;
    position:Point;
    
    updater:Timer;
    frameNum:Integer; //Номер текущего кадра анимации
    
    procedure ChangeSprite();
    begin
      tsprite := sprite;
      sprite:= new PictureWPF(position, curAnim.frames[frameNum]);
      tsprite.Destroy;
    end;
    
    //Обновление кадра изображения
    procedure UpdateFrame();
    begin
      if (frameNum<curAnim.frames.Length-1) then
        frameNum+=1
      else
        if not (curAnim.isLoop) then begin
          //PlayAnim(defaultAnim);
          exit;
        end
        else frameNum:=0;
        
      ChangeSprite();
    end;
    
    procedure SetPos(pos:Point);
    begin
      sprite.MoveTo(pos.X, pos.Y);
      position := pos;
    end;
    
    public
    ///Конструктор с инициализацией стандартной анимации с обычными параметрами
    constructor Create(x,y:integer; aname:string; frames:array of string);
    begin
      x := x * 48; y := y * 48;
      anims := new Dictionary<string, spriteInfo>();
      defaultAnim:=aname;
      AddAnim(aname, frames, 160, True); //Обычно анимация зациклена
      sprite := new PictureWPF(x,y,anims[defaultAnim].frames[0]);
    end;
    
    ///Конструктор с инициализацией стандартной анимации
    constructor Create(x,y:integer; aname:string; frames:array of string; speed:integer; looped:boolean);
    begin
      x := x * 48; y := y * 48;
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
      curAnimName := aname;
      curAnim := anims[aname];
      if (updater <> nil) then updater.Stop();
      frameNum := 0;
      if (curAnim.frames.Length>1) then begin
        updater := new Timer(curAnim.speed, UpdateFrame);
        updater.Start();
      end;
      
      ChangeSprite();
    end;
    
    ///Устанавливает позицию спрайта
    property Pos: Point write SetPos;
    property CurrentAnim: string read curAnimName;
  end;
  
  ///Загружает спрайт с именем sname.
  function LoadSprite(sname:string):array of string;
  begin
    Result := new string[1];
    Result[0] := 'img/'+sname+'.png';
  end;
  
  ///Загружает последовательность спрайтов с именем sname и номерами от 1 до count.
  function LoadSprites(sname:string; count:integer):array of string;
  begin
    Result := new string[count];
    for var i:= 0 to count-1 do begin
      Result[i] := 'img/'+sname+(i+1)+'.png';
    end;
  end;
  
  type
  ///Класс игрока в "мире".
  PlayerWorld = class
    private
    point:RectangleWPF;
    position:record x,y:integer end;
    sprite:LSprite;
    moveTimer, idleTimer:Timer;
    
    public
    constructor Create(x,y:integer);
    begin
      position.x := x; position.y := y;
      point := new RectangleWPF(x*48, y*48, 4,4,Colors.Black);
      point.Visible := false;
      
      //Инициализация изображений игрока
      sprite := new LSprite(x, y, 'idledown', LoadSprite('player/down2'), 160, false);
      sprite.AddAnim('idleleft', LoadSprite('player/left3'), 160, true);
      sprite.AddAnim('idleright', LoadSprite('player/right1'), 160, true);
      sprite.AddAnim('idleup', LoadSprite('player/up2'), 160, true);
      
      sprite.AddAnim('walkleft', LoadSprites('player/left', 5), 120, false);
      sprite.AddAnim('walkright', LoadSprites('player/right', 5), 120, false);
      sprite.AddAnim('walkup', LoadSprites('player/up', 4), 120, false);
      sprite.AddAnim('walkdown', LoadSprites('player/down', 4), 120, false);
      
      sprite.PlayAnim('idledown');
      //*************************
      
      //Обновляем покадрово позицию визуального представления игрока
      OnDrawFrame += procedure(dt:real) -> begin
        sprite.Pos := point.LeftTop;
      end;
    end;
    
    procedure MoveOn(x,y:integer; dir:string);
    begin
      writeln(Objects.Count);
      //Не обрабатываем движение, если персонаж уже идёт
      if (moveTimer<>nil) and (moveTimer.Enabled) then exit;
      if (idleTimer<>nil) then idleTimer.Stop();
      //Обрабатываем "поворот" игрока, включая соответствующую анимацию
      //if (sprite.CurrentAnim <> 'walk'+dir) then
        sprite.PlayAnim('walk'+dir);
      position.x := x; position.y := y;
      point.AnimMoveTo(x*48, y*48, 0.58);
      //Таймер нужен чтобы игрок не двигался с бесконечным ускорением
      moveTimer := new Timer(560, procedure()->
      begin
//        idleTimer := new Timer(80, procedure()-> 
//        begin
//          sprite.PlayAnim('idle'+dir);
//          idleTimer.Stop();
//        end);
//        idleTimer.Start();
        moveTimer.Stop();
      end);
      moveTimer.Start();
    end;
    
    procedure Finalize(); override;
    begin
      
    end;
    
    property GetX: integer read position.x;
    property GetY: integer read position.y;
  end;
end.