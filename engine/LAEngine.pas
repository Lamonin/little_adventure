unit LAEngine;
{$reference Newtonsoft.Json.dll}
uses Newtonsoft.Json.Linq;
uses GraphWPF, WPFObjects, Timers, Loader;

procedure CombatField(); forward;

///Проверяет - принадлежит ли точка прямоугольнику объекта
function PtInside(x,y:real; obj:ObjectWPF):boolean;
begin
  if (x>obj.LeftTop.X) and (x<obj.RightTop.X) and (y>obj.LeftTop.Y) and (y<obj.RightBottom.Y) then
  Result:=True;
end;

///Меняет изображение from на изображение из файла по пути too.
procedure ChangePicture(var from:PictureWPF; too:string);
begin
  var p := from;
  from := new PictureWPF(p.LeftTop, too);
  p.Destroy();
end;

///Умножает цвет объекта на mult, делая его ярче/темнее.
procedure Tint(var obj:ObjectWPF; mult:real);
begin
  var c := obj.Color;
  var R := round(c.R*mult); if R>255 then R:= 255 else if R<0 then R := 0;
  var G := round(c.G*mult); if G>255 then G:= 255 else if G<0 then G := 0;
  var B := round(c.B*mult); if B>255 then B:= 255 else if B<0 then B := 0;
  obj.Color := ARGB(255, R, G, B);  
end;

type
  ///Получение и изменение значений в файле JSON формата.
  LALoader = class
    private
    jObj:JObject; //Хранит весь наш файл для дальнейшней работы с ним
    path:string;
    
    public
    ///Говорим "обрабатывать" файл с JSON структурой по пути path
    constructor Create(path:string);
    begin
      //Считываем текст из файла
      self.path := path;
      //Загружаем текстовый файл и преобразуем в структуру JSON.NET библиотеки
      jObj := JObject.Parse(ReadAllText(path, Encoding.UTF8));
    end;
    
    ///Получаем значение по пути ключей. Где TL - необходимо указать тип значения.
    ///'$.' - в начале пути приписывать ОБЯЗАТЕЛЬНО!
    ///Например: GetValue&<integer>('$.enemy.zombie.hp'); //знак & - тоже обязателен.
    function GetValue<TL>(key:String):TL;
    begin
      var token := jObj.SelectToken(key);
      if (token = nil) then writeln('Такого ключа не существует!')
      else Result := token.ToObject&<TL>();
    end;
    
    ///Устанавливает значение val по пути key в файле json,
    ///если такой путь существует!
    ///Например: SetValue('$.enemy.zombie.hp', 100);
    procedure SetValue<TL>(key:string; val:TL);
    begin
      var v := JToken.FromObject(val as Object);
      var token := jObj.SelectToken(key);
      if (token = nil) then writeln('Такого ключа ', key, ' не существует!')
      else token.Replace(v);
    end;
    
    ///Сохраняет изменения в файле
    procedure SaveFile();
    begin
      WriteAllText(path,jObj.ToString(), Encoding.UTF8);
    end;
  end;
  //##############-НАЧАЛО_ИНТЕРФЕЙС-################
  ///Пример использования:
  ///var b:= new LAButton(100, 200, 'img/ui/play.png', 'img/ui/playpress.png');
  ///b.OnClick += procedure() -> begin КОД КОТОРЫЙ ВЫПОЛНИТСЯ ПРИ НАЖАТИИ КНОПКИ end;
  LAButton = class
    private
    pic:PictureWPF;
    isClicked:boolean;
    idlePic, clickPic, buttonText:string;
    
    ///Изменение спрайта на clickPic
    procedure ClickedSprite(x, y: real; mousebutton: integer);
    begin
      if (pic = nil) then exit;
      if (mousebutton <> 1) and (isClicked) then exit;
      if PtInside(x,y,pic) then begin
        isClicked := True;
        ChangePicture(pic, clickPic);
        ApplyText();
      end;
    end;
    
    ///Обработка нажатия
    procedure ProcessSprite(x, y: real; mousebutton: integer);
    begin
      if (pic = nil) then exit;
      ChangePicture(pic, idlePic);
      ApplyText();
      if (mousebutton <> 0) then exit;
      if (OnClick <> nil) and PtInside(x,y,pic) and (isClicked) then begin
        OnClick();
      end;
      isClicked := false;
    end;
    
    procedure ApplyText();
    begin
      if (buttonText = '') or (pic = nil) then exit;
      pic.Text := buttonText;
      pic.FontName := 'GranaPadano';
      pic.FontColor := ARGB(255, 255, 214, 0);
      pic.FontSize := 32;
      pic.TextAlignment := Alignment.Center;
    end;
    
    procedure SetText(t:string);
    begin
      buttonText := t;
      ApplyText();
    end;
    
    public
     //Событие нажатия на кнопку
    OnClick: procedure;
    ///Создаем кнопку с изображением по умолчанию idlePic
    ///И с изображением по нажатию clickPic.
    constructor Create(x,y:integer; idlePic, clickPic:string);
    begin
      self.idlePic := 'img\ui\' + idlePic;
      self.clickPic := 'img\ui\' + clickPic;
      
      pic := new PictureWPF(x, y, self.idlePic);
      OnMouseDown += ClickedSprite;
      OnMouseUp += ProcessSprite;
    end;
    
    procedure Destroy();
    begin
      if (pic = nil) then exit;
      OnMouseDown -= ClickedSprite;
      OnMouseUp -= ProcessSprite;
      self.pic.Destroy();
      self.pic := nil;
    end;
    
    property Text: string read buttonText write SetText;
  end;
  
  //##############-КОНЕЦ_ИНТЕРФЕЙС-#################
  
  //##############-НАЧАЛО_СПРАЙТЫ-################
  spriteInfo=record
    frames:array of string; //Кадры анимации
    speed:integer; //Скорость анимации
    isLoop:boolean; //Зациклена ли анимация
  end;
  
  LSprite = class
    private
    anims:Dictionary<string, spriteInfo>; //Все анимации по их именам
    curAnim:spriteInfo; //Текущая анимация
    sprite:PictureWPF;
    position:Point;
    updater:Timer;
    frameNum:Integer; //Номер текущего кадра анимации
    isVisible:boolean;
    
    procedure ChangeSprite();
    begin
      Redraw(procedure()-> begin
        var p := sprite.LeftTop;
        sprite.Destroy();
        sprite:= new PictureWPF(p, curAnim.frames[frameNum]);
      end);
      sprite.Visible := isVisible;
    end;
    
    //Обновление кадра изображения
    procedure UpdateFrame();
    begin
      if (frameNum<curAnim.frames.Length-1) then frameNum+=1
      else if curAnim.isLoop then frameNum:=0
      else begin updater.Stop(); exit; end;
      ChangeSprite();
    end;
    
    function GetPos():Point;
    begin
      if (sprite <> nil) then
        Result := sprite.Center;
    end;
    
    ///Устанавливает позицию спрайта
    procedure SetPos(pos:Point);
    begin
      position := pos;
      pos.X += 24;
      sprite.Center := pos;
    end;
    
    function GetFrameCount():integer;
    begin
       Result:= curAnim.frames.Length;
    end;

    public
    ///Конструктор с инициализацией стандартной анимации с обычными параметрами
    constructor Create(x,y:integer; aname:string; frames:array of string);
    begin
      Create(x,y,aname, frames, 160, True);
    end;
    
    ///Конструктор с инициализацией стандартной анимации
    constructor Create(x,y:integer; aname:string; frames:array of string; speed:integer; looped:boolean);
    begin
      Visible := True;
      position.x := x * 48; position.y := y * 48;     
      anims := new Dictionary<string, spriteInfo>();
      AddAnim(aname, frames, speed, looped);
      sprite := new PictureWPF(position, anims[aname].frames[0]);
      SetPos(position);
    end;
   
    ///Принадлежит ли точка спрайту
    function PtInside(x,y:Real):boolean;
    begin
      result := LAEngine.PtInside(X,Y,sprite);
    end;
    
    ///Добавляет новую анимацию с именем aname
    procedure AddAnim(aname:string; frames:array of string; speed:integer; looped:boolean);
    begin
      var frame:spriteInfo;
      frame.frames:= frames; frame.speed:=speed; frame.isLoop:=looped;
      anims.Add(aname, frame);
    end;
    
    ///Проигрывает анимацию с именем aname
    procedure PlayAnim(aname:string);
    begin
      curAnim := anims[aname];
      if (updater <> nil) then updater.Stop();
      frameNum := 0;
      if (curAnim.frames.Length>1) then begin
        updater := new Timer(curAnim.speed, UpdateFrame);
        updater.Start();
      end;
      ChangeSprite();
    end;
    
    ///Уничтожаем спрайт.
    procedure Destroy();
    begin
      sprite.Destroy();
      sprite := nil;
      updater.Stop();
    end;
    
    ///Устанавливает позицию спрайта
    property Pos: Point Read GetPos write SetPos;
    ///Количество фреймов текущей анимации
    property CurrentFrameCount: Integer Read getFrameCount;
    ///Видимость спрайта
    property Visible: boolean write isVisible read isVisible;
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
  //##############-КОНЕЦ_СПРАЙТЫ-################
  
  type
  //ОПИСАНИЕ ИНТЕРФЕЙСНОЙ ЧАСТИ
  ITransitionPic = interface
    procedure Show();
    procedure Hide();
    procedure ToFront();
    property CanHide:boolean read;
  end;

  IUseObject = interface
    procedure CreateEnemyPoint(ArrayEnemy: array of string; X,Y: integer);
    procedure CreateNextLevel(levelName:string);
    procedure CreateMessage(messages:array of string);
    procedure StartBattle();
    function NextMessage():boolean;
    property objType: string read;
    property NextLevelName: string read;
  end;
  
  IPlayerWorld = interface
    procedure SetPos(x,y:integer);
    procedure MoveOn(x,y:integer; dir:string);
    procedure UseGrid();
    procedure Destroy();
    property GetX: integer read;
    property GetY: integer read;
    property isBlocked: boolean read write;
  end;
  
  levelGridRecord = record
    CantGet:boolean; //Можно ли ступить на клетку
    CanUse:boolean; //Можно ли взаимодействовать
    GridObject:IUseObject; //Объект на клетке
  end;
  
  levelGridArr = array[0..15, 0..26] of levelGridRecord;
  
  ///Общие данные игры по ходу её выполнения
  ///Обращение к данным делается, например, так: LAGD.Player
  LAGD = static class
    private
    static pplayer:IPlayerWorld;
    static llevelGrid:levelGridArr;
    static llevelPicture, CCombatPic, backgroundPic:PictureWPF;
    static ttransPic:ITransitionPic;
    public
    ///Персонаж игрока в обычном уровня
    static property Player: IPlayerWorld read pplayer write pplayer;
    ///Сетка уровня
    static property Grid: levelGridArr read llevelGrid write llevelGrid;
    ///Изображение обычного уровня
    static property LevelPic: PictureWPF read llevelPicture write llevelPicture;
    ///Изображение боевого уровня
    static property CombatPic: PictureWPF read CCombatPic write CCombatPic;
    static property TransPic: ITransitionPic read ttransPic write ttransPic;
    static property GetBackground: PictureWPF read backgroundPic write backgroundPic;
  end;
  
  IBattleEntity = interface
    procedure Destroy();
    procedure Death();
    procedure Damage(Dmg: integer);
    procedure Attack(E: IBattleEntity); 
    property ThisLock: Boolean Read Write;   
    property Pname: string Read Write ;
    property PicC: PictureWPF Read Write;
    property GetHP: integer Read;
    Function AddAction():boolean;
  end;
  //КОНЕЦ ОПИСАНИЯ ИНТЕРФЕЙСНОЙ ЧАСТИ

  BattleProcessor = class
    private
      static CombatTimer: Timer;
      static Stoptimer: boolean;
      static ListEnemy: array of IBattleEntity;
      static PPlayerBattle: IBattleEntity;
      static SLEnemy: IBattleEntity;
    public
     static procedure StartBattle();
        begin
        CombatTimer := new Timer(250, procedure() ->
      begin
          //if (stopTimer) then exit;
          var ActionList:= new List<IBattleEntity>();
          
        foreach var t in ListEnemy do 
        begin
         if t.AddAction() then ActionList.Add(t);                 
        end;
         if (ActionList.Count>0) then
         begin       
           Stoptimer:= true;
           foreach var E in ActionList do begin  if PPlayerBattle.GetHP <=0 then begin CombatTimer.Stop; exit end; E.Attack(PPlayerBattle); end;
         end;
      end);
        CombatTimer.Start;
        end;
      static property PlayerBattle: IBattleEntity Read PPlayerBattle Write PPlayerBattle; 
      static property EnemyList: array of IBattleEntity Read ListEnemy Write ListEnemy;
      static property selectedEnemy: IBattleEntity Read SLEnemy Write SLEnemy;
  end;

  BattleEntity = class(IBattleEntity) 
    private
     name: string;
     hp, attackDmg, agility, actionPoint : integer;
     Sprite : LSprite;
     LockThis : boolean;
     CPic: PictureWPF;
     
     ///Нажатие на врага в бою
     procedure klik(x, y: real; mousebutton: integer);
     begin
       if (Sprite <> nil) and (mousebutton=1) and (Sprite.PtInside(x,y)) and not(ThisLock) then begin
        if (BattleProcessor.SLEnemy<>nil) then
         begin
           BattleProcessor.SLEnemy.PicC.Destroy;        
           BattleProcessor.SLEnemy.ThisLock:= false;
         end;
         PicC:= new PictureWPF(Sprite.Pos.X-65,Sprite.Pos.Y+15,'img\enemy\circle.png');
         ThisLock:=true;
         BattleProcessor.SLEnemy:=self; 
       end;
     end;
     
    public
     constructor Create();
     begin
       OnMouseDown += klik;
     end;
     
     function AddAction():boolean;
     begin
       actionPoint+= agility;
       if actionPoint >=10 then 
       begin
         actionPoint-=10;
         result:= true;
         end;
     end;
    
     procedure Destroy();
     begin
      Sprite.Destroy;
     end;
      
     procedure Death();virtual;
     begin
      Sprite.PlayAnim('Death');
     end;
      
     procedure Damage(Dmg: integer);virtual;
      begin
        hp -= Dmg;
        if (hp<=0) then Death();
      end;
      
     procedure Attack(E: IBattleEntity);virtual;      
      begin
        E.Damage(AttackDmg);
        Sprite.PlayAnim('attack');
        
      end; 
      property GetHP: integer Read hp;
      property Pname: string Read name Write name;
      property ThisLock: Boolean Read LockThis Write LockThis;
      property PicC: PictureWPF Read CPic Write CPic;
  end;
  
  SkeletonEnemy = class(BattleEntity)
   private 
   
   public
   
   constructor Create(X, Y:integer);
   begin
     attackDmg:=4;
     agility:=3;
     hp:= 10;
     name := 'Skeleton';
     writeln(X,Y:10);
     Sprite:= new LSprite(X,Y,'Idle',LoadSprites('enemy\Skeleton_Seeker\idle', 6));
     Sprite.AddAnim('Attack', LoadSprites('enemy\Skeleton_Seeker\death', 5), 160, false);
     Sprite.AddAnim('Death', LoadSprites('enemy\Skeleton_Seeker\death', 5), 160, false);
     Sprite.PlayAnim('Idle');
   end;
   
  end;
  
  TreeEnemy = class(BattleEntity)
   private 
   
   public
   
   constructor Create(X, Y:integer);
    begin
     attackDmg:=1;
     agility:=4;
     hp:=15;
     name := 'TreeEnemy';
     Sprite:= new LSprite(X,Y,'Idle',LoadSprites('enemy\Sprout\idle', 4));
     Sprite.AddAnim('Attack', LoadSprites('enemy\Sprout\attack', 6), 160, false);
     Sprite.AddAnim('Death', LoadSprites('enemy\Sprout\death', 8), 160, false);
     Sprite.PlayAnim('Idle');
    end;
   end;
  
  BattlePlayre = class(BattleEntity)
  private
  
  public
  constructor create();
    begin
    hp:=20;
    attackDmg:=5;
    agility:=2;
    name:= 'Player';
    end;
   procedure Attack(E: IBattleEntity);override;      
      begin
        if (E = nil) then exit;
        E.Damage(AttackDmg);
      end;
      
    procedure Death();override;
     begin
      Writeln('Babah');
     end;
      
     procedure Damage(Dmg: integer);override;
      begin
        hp -= Dmg;
        if (hp<=0) then Death();
      end;
  end;
  
  
  UseObject = class(IUseObject)
    private
    typeObject:string;
    static dialogBanner:PictureWPF;
    messages:array of string;
    messageNum:integer;
    messageCount:integer;
    levelName:string;
    messageTimer:Timer;
    EnemyPoint:array of string;
    static enemyPoints:List<Point>;
    
    public 
    static constructor();
    begin
      enemyPoints := new List<Point>();
    end;
    
    ///Рассчитываем расстояние до точек начала боя
    ///выбираем самое короткое из них.
    static function CalculateEnemyPoint():integer;
    var min:integer;
    begin
      min:= 100;
      if (enemyPoints.Count<=0) then exit;
      for var i:=0 to enemyPoints.Count-1 do 
      begin
        result:= Round(Sqrt((enemyPoints[i].x - LAGD.Player.GetX)**2 + (enemyPoints[i].y - LAGD.Player.GetY)**2));
        if (Result < min) then min := Result;
      end;
      Writeln(min);
    end;
    
    static procedure ClearEnemyPointsList();
    begin
      if (enemyPoints<>nil) then enemyPoints.Clear();
    end;
    
    procedure CreateEnemyPoint(ArrayEnemy: array of string; X,Y: integer);
    begin
      writeln(ArrayEnemy);
      typeObject := 'EnemyPoint';
      EnemyPoint := ArrayEnemy;
      var p : GPoint;
      P.X :=X;
      p.Y :=Y;
      enemyPoints.add(p);
    end;
    
    ///Начало битвы, спавн врагов
    procedure StartBattle();
    begin
      BattleProcessor.EnemyList:= new IBattleEntity[EnemyPoint.Length];
      for var i:= 0 to EnemyPoint.Length-1 do
       begin
        case (i+1) of
           1: CreateEnemy(i, 12, 4);
           2: CreateEnemy(i, 15, 2);
           3: CreateEnemy(i, 9, 2);
           4: CreateEnemy(i, 6, 4);
           5: CreateEnemy(i, 18, 4);
          end;
      end;
    end;
    
    procedure CreateEnemy(Index:integer; X,Y:integer);
    begin
      var E: BattleEntity;
      case EnemyPoint[Index] of
      'Skeleton':begin
        E:= new SkeletonEnemy(X,Y);
      end;
      'TreeEnemy':begin
        E:= new TreeEnemy(X,Y);
      end;
      end;
      BattleProcessor.EnemyList[Index]:= E;
    end;
    
    procedure CreateNextLevel(levelName:string);
    begin
      typeObject := 'nextLevel';
      self.levelName := levelName;
    end;

    procedure CreateMessage(messages:array of string);
    begin
      typeObject := 'message';
      self.messages := messages;
      if (dialogBanner = nil) then Redraw(procedure() -> begin
        dialogBanner := new PictureWPF(0,768-128,'img\ui\rect_game_big.png');
        dialogBanner.FontSize := 24;
        dialogBanner.FontColor := Colors.Yellow;
        dialogBanner.Visible := false;
      end);
    end;
    
    function NextMessage():boolean;
    begin
      if (messageTimer<>nil) and (messageTimer.Enabled) then
      begin
        messageTimer.Stop();
        dialogBanner.Text := messages[messageNum];
        exit;
      end;
      
      if dialogBanner.Visible then begin
        messageNum += 1;
      end
      else begin
        messageNum := 0;
        dialogBanner.Visible := true;
      end;
      
      if (messageNum = messages.Length) then begin
        dialogBanner.Visible := false;
        messageNum := 0; //Надо сбросить это значение
        Result := False;
        exit;
      end;
      messageCount := 1;
      dialogBanner.Text := '';
      messageTimer := new Timer(16, procedure() -> begin
        dialogBanner.Text += messages[messageNum][messageCount];
        if (messageCount = messages[messageNum].Length) then
          messageTimer.Stop();
        messageCount += 1;
      end);
      messageTimer.Start();
      Result := True;
    end;
    
    ///Возвращает тип этого объекта
    property objType: string read typeObject;
    ///Возвращает название уровня на который ведет этот объект
    property NextLevelName: string read levelName;
  end;
  
  ///Класс игрока в "мире".
  PlayerWorld = class (IPlayerWorld)
    private
    point:RectangleWPF; //Невидимое тело объекта
    useRect:PictureWPF;
    position:record x,y:integer end;
    sprite:LSprite;
    moveTimer, updateSprite:Timer;
    dir:string;
    isUsing, blocked:boolean;
    
    procedure Blocking(blocked:boolean);
    begin
      self.blocked := blocked;
      sprite.Visible := not blocked;
    end;
    
    //Проверяет можно ли использовать клетку на которую смотрит персонаж
    procedure CheckGridUse();
    begin
      var dx := 0; var dy := 0;
      case self.dir of 
        'left': dx := -1;
        'right': dx := 1;
        'up': dy := -1;
        'down': dy := 1;
      end;
      //Так как это граница экрана, то проверяем точку перехода на след. уровень.
      if (GetX+dx<0) or (GetX+dx>26) or (GetY+dy<0) or (GetY+dy>15) then 
      begin
        //Можно взаимодействовать - значит это точка перехода
        useRect.Visible := LAGD.Grid[GetY, GetX].CanUse;
        exit; 
      end;
      if (LAGD.Grid[GetY+dy, GetX+dx].GridObject <> nil) and (LAGD.Grid[GetY+dy, GetX+dx].GridObject.objType = 'nextLevel') then exit;
        useRect.Visible := LAGD.Grid[GetY+dy, GetX+dx].CanUse;
      UseObject.CalculateEnemyPoint();
      var l := LAGD.Grid[LAGD.player.GetY,LAGD.player.GetX].GridObject;
      if (l <> nil) and (l.Objtype = 'EnemyPoint') then CombatField();
    end;
    
    public
     //Заблокировано ли управление игроком
    constructor Create(x,y:integer);
    begin
      position.x := x; position.y := y;
      point := new RectangleWPF(x*48, y*48, 4, 4, Colors.Black);
      point.Visible := false;
      useRect := new PictureWPF(x*48+12, y*48, 'img\ui\rect_small.png');
      useRect.TextAlignment := Alignment.Center;
      useRect.FontColor := Colors.Yellow;
      useRect.FontSize := 18;
      useRect.Text := 'E';
      useRect.Visible := false;
      
      //Инициализация изображений игрока
      sprite := new LSprite(x, y, 'idledown', LoadSprite('player/down2'), 160, false);
      
      sprite.AddAnim('rotateleft', LoadSprite('player/left4'), 100, false);
      sprite.AddAnim('rotateright', LoadSprite('player/right4'), 100, false);
      sprite.AddAnim('rotateup', LoadSprite('player/up2'), 100, false);
      sprite.AddAnim('rotatedown', LoadSprite('player/down2'), 100, false);
      
      sprite.AddAnim('walkleft', LoadSprites('player/left', 4), 160, false);
      sprite.AddAnim('walkright', LoadSprites('player/right', 4), 160, false);
      sprite.AddAnim('walkup', LoadSprites('player/up', 4), 160, false);
      sprite.AddAnim('walkdown', LoadSprites('player/down', 4), 160, false);
      
      sprite.PlayAnim('idledown');
      //*************************
      
      //Обновляем позицию визуального представления игрока
      updateSprite := new Timer(10,procedure() -> begin
        sprite.Pos := point.LeftTop;
        useRect.MoveTo(point.LeftTop.x+12, point.LeftTop.y-48);
      end);
      updateSprite.Start();
    end;
    
    ///Перемещает игрока в координаты x, y
    procedure SetPos(x,y:integer);
    begin
      position.x := x; position.y := y;
      point.AnimMoveTo(x*48,y*48, 0);
      sprite.PlayAnim('idledown');
      CheckGridUse();
    end;
    
    procedure MoveOn(x,y:integer; dir:string);
    begin
      if isUsing then exit;
      self.dir := dir;
      //Не обрабатываем движение, если персонаж уже идёт
      if (moveTimer<>nil) and (moveTimer.Enabled) then exit;
      
      //Проверяем возможность "хода", в случае отсутствия просто "поворачиваем"
      //персонажа в нужную сторону.
      if (GetX+x<0) or (GetX+x>26) or (GetY+y<0) or (GetY+y>15) or LAGD.Grid[GetY+y, GetX+x].CantGet then 
        sprite.PlayAnim('rotate'+dir)
      else begin
        //Обрабатываем "поворот" и движение игрока, включая соответствующую анимацию
        sprite.PlayAnim('walk'+dir);
        position.x += x; position.y += y;
        point.AnimMoveTo(GetX*48, GetY*48, 0.64);
        
        //Таймер нужен чтобы игрок не двигался с бесконечным ускорением
        moveTimer := new Timer(640, procedure() -> moveTimer.Stop());
        moveTimer.Start();
      end;
      CheckGridUse();   
    end;
      
    procedure UseGrid();
    begin
      var dx := 0; var dy := 0;
      case self.dir of 
        'left': dx := -1;
        'right': dx := 1;
        'up': dy := -1;
        'down': dy := 1;
      end;
      if (GetX+dx<0) or (GetX+dx>26) or (GetY+dy<0) or (GetY+dy>15) then exit;
      if not LAGD.Grid[GetY+dy, GetX+dx].CanUse then exit;
      var obj := LAGD.Grid[GetY+dy, GetX+dx].GridObject;
      case obj.objType of
        'message': isUsing := obj.NextMessage();
      end;
    end;
    
    ///Уничтожаем объект игрока.
    procedure Destroy();
    begin
      moveTimer.Stop();
      updateSprite.Stop();
      point.Destroy();
      useRect.Destroy();
      sprite.Destroy();
    end;
    
    property GetX: integer read position.x;
    property GetY: integer read position.y;
    property isBlocked: boolean read blocked write Blocking;
  end;
  
  TransitionPic = class (ITransitionPic)
    private
    pic:RectangleWPF;
    isCanHide:boolean;
    public
    constructor Create;
    begin
      Redraw(procedure()-> begin
        pic := new RectangleWPF(0, 0, 1296, 768, Colors.Black);
        pic.FontColor := Colors.White;
        pic.FontSize := 24;
        pic.TextAlignment := Alignment.Center;
        pic.Visible := false;
      end);
    end;
    
    ///Показать изображение перехода
    procedure Show();
    begin
      Show('Для продолжения нажмите SPACE');
    end;
    
    ///Показать изображение перехода с нужным текстом после загрузки
    procedure Show(message:string);
    begin
      if (LAGD.player <> nil) then
        LAGD.player.isBlocked := true; //Блокируем движение игрока
      Redraw(procedure()-> begin
        pic.Visible := true;
        pic.Text := 'Загрузка уровня...';
      end);
      var t:Timer;
      t := new Timer(1000, procedure() -> begin
        isCanHide := true;
        pic.Text := message;
        t.Stop();
      end);
      t.Start();
    end;
    
    ///Скрыть изображение перехода
    procedure Hide();
    begin
      LAGD.player.isBlocked := false; //Разблокируем движение игрока
      isCanHide := false;
      pic.Visible := false;
    end;
    
    procedure ToFront();
    begin if (pic <> nil) then pic.ToFront(); end;
    
    property CanHide:boolean read isCanHide;
  end;
  
  ///Загружает уровень с именем lname и настраивает сетку grid.
  procedure LoadLevel(lname:string);
  begin
    var loader := new LALoader('data/levels/LALevels.ldtk');
    
    var i := -1;
    //Находим номер уровня в массиве
    for i := 0 to loader.GetValue&<JToken>('$.levels').Count()-1 do begin
      if loader.GetValue&<string>('$.levels['+i+'].identifier') = lname then break;
    end;
    
    var val := loader.GetValue&<JToken>('$.levels['+i+'].layerInstances[0].entityInstances');
    var x,y:integer;
    for var j:=0 to val.Count()-1 do begin
      x := Integer(val[j]['__grid'][0]);
      y := Integer(val[j]['__grid'][1]);
      var cell := LAGD.Grid[y,x];
      ///Определя
      case val[j]['__identifier'].ToString() of
        'Wall': cell.CantGet := true;
        'SpawnPoint': begin
          if (LAGD.Player = nil) then LAGD.Player := new PlayerWorld(x,y)
          else LAGD.Player.SetPos(x,y);
        end;
        'MessageObject': begin
          //Можно ли "наступить" на объект взаимодействия
          var vval := val[j]['fieldInstances'];
          if (vval[1]['__value'].ToString() = 'False') then cell.CantGet := true;
          cell.CanUse := true;
          cell.GridObject := new UseObject();
          cell.GridObject.CreateMessage(vval[0]['__value'].ToObject&<array of string>());
        end;
        'NextLevel': begin
          cell.CanUse := true;
          cell.GridObject := new UseObject();
          var tt := val[j]['fieldInstances'][0]['__value'].ToString();
          cell.GridObject.CreateNextLevel(tt);
        end;
        'EnemyPoint': begin
          cell.GridObject := new UseObject();
          var tt:= val[j]['fieldInstances'][0]['__value'].ToObject&<array of string>();
          cell.GridObject.CreateEnemyPoint(tt, x, y);
        end;
//        'TransitionMessage': begin
//          var tt:= val[j]['fieldInstances'][0]['__value'].ToString();
//          var p := new RectangleWPF(100, 100, 400, 100, Colors.Wheat);
//          p.Text := tt;
//          p.FontName := 'Promocyja';
//          p.TextAlignment := Alignment.Center;
//        end;
      end;
      LAGD.Grid[y,x] := cell;
    end;
    //Устанавливаем изображение уровня
    LAGD.LevelPic := new PictureWPF(0, 0,'data/levels/LALevels/png/'+lname+'.png');
    LAGD.LevelPic.ToBack(); //Перемещаем картинку уровня назад
  end;
  
  ///Закрывает текущий уровень
  procedure CloseLevel();
  begin
    LAGD.TransPic.Show(); //Включаем экран перехода
    if (LAGD.LevelPic = nil) then exit;
    LAGD.LevelPic.Destroy(); //Уничтожаем старое изображение уровня
    UseObject.ClearEnemyPointsList(); //Уничтожаем точки врагов
    var t : levelGridArr; //
    LAGD.Grid := t; // Обнуляем таким образом сетку уровня
  end;
  
  ///Меняет текущий уровень на уровень с именем lname
  procedure ChangeLevel(lname:string);
  begin
    CloseLevel();
    LoadLevel(lname);
  end;
  
  procedure Escape();
  begin
      // LAGD.CombatPic.Destroy();
       LAGD.Player.isBlocked:= false;
  end;
  
  procedure CombatField();
  begin
    LAGD.Player.isBlocked := true; //Блокируем управление игроком
    LAGD.CombatPic := new PictureWPF(0, 0,'data\levels\LALevels\png\CombatField.png');
    ///По позиции игрока начинаем бой.
    LAGD.Grid[LAGD.Player.GetY,LAGD.Player.GetX].GridObject.StartBattle();
    if (BattleProcessor.PlayerBattle <> nil) then BattleProcessor.PlayerBattle.Destroy;
    BattleProcessor.PlayerBattle:= new BattlePlayre;
     var b:= new LAButton(12*48, 10*48, 'play.png', 'playpress.png');
     b.OnClick += procedure() -> begin 
      battleprocessor.PlayerBattle.Attack(BattleProcessor.SLEnemy);     
     end;
     BattleProcessor.StartBattle();
  end; 
  
  //РАЗДЕЛ ОПИСАНИЯ ГЛАВНОГО МЕНЮ
  procedure DrawMainMenu(); forward;
  
  procedure DrawConfirmMenu(text:string; confirm, cancel:procedure);
  var b_confirm, b_cancel: LAButton;
  begin
    var r_body := new PictureWPF(384, 280, 'img\ui\rect_confirm.png');
    r_body.Text := text;
    r_body.FontName := 'GranaPadano';
    r_body.FontColor := ARGB(255, 255, 214, 0);
    r_body.FontSize := 32;
    r_body.TextAlignment := Alignment.Center;
    
    b_confirm := new LAButton(384, 424, 'rect_menu_rules_wide.png', 'rect_menu_rules_wide_click.png');
    b_confirm.Text := 'ОК';
    b_cancel := new LAButton(656, 424, 'rect_menu_rules_wide.png', 'rect_menu_rules_wide_click.png');
    b_cancel.Text := 'ОТМЕНА';
    
    b_confirm.OnClick := procedure() -> begin 
      confirm; 
      r_body.Destroy(); b_confirm.Destroy(); b_cancel.Destroy(); 
    end;
    
    b_cancel.OnClick := procedure() -> begin
      cancel; 
      r_body.Destroy(); b_confirm.Destroy(); b_cancel.Destroy(); 
    end;
  end;
  
  procedure DrawRulesMenu();
  var b_prev, b_next, b_back:LAButton;
  begin
    b_prev := new LAButton(309, 598, 'rect_menu_rules_wide.png', 'rect_menu_rules_wide_click.png');
    b_prev.Text := 'ПРЕДЫДУЩИЙ';
    
    b_back := new LAButton(581, 598, 'rect_menu_rules_short.png', 'rect_menu_rules_short_click.png');
    b_back.Text := 'В МЕНЮ';
    
    b_next := new LAButton(731, 598, 'rect_menu_rules_wide.png', 'rect_menu_rules_wide_click.png');
    b_next.Text := 'СЛЕДУЮЩИЙ';
    
    b_back.OnClick := procedure() -> begin
      DrawMainMenu();
      b_prev.Destroy(); b_back.Destroy(); b_next.Destroy();
    end;
  end;
  
  procedure DrawMainMenu();
  var b_continue, b_startNew, b_rules, b_about, b_exit:LAButton;
  begin
    var loader := new LALoader('data/userdata.json');
    
    b_continue := new LAButton(32, 694, 'rect_menu_wide.png', 'rect_menu_wide_click.png');
    b_continue.Text := 'ПРОДОЛЖИТЬ'; 
    
    b_startNew := new LAButton(345, 694, 'rect_menu_wide.png', 'rect_menu_wide_click.png');
    b_startNew.Text := 'НОВАЯ ИГРА';
    
    b_rules := new LAButton(656, 694, 'rect_menu_short.png', 'rect_menu_short_click.png');
    b_rules.Text := 'ПРАВИЛА';
   
    b_about := new LAButton(864, 694, 'rect_menu_short.png', 'rect_menu_short_click.png');
    b_about.Text := 'О ПРОЕКТЕ';

    ///Завершает работу игры.
    b_exit := new LAButton(1072, 694, 'rect_menu_short.png', 'rect_menu_short_click.png');
    b_exit.Text := 'ВЫХОД';
    
    //Делегат, при вызове удаляет кнопки
    var delButtons := procedure() -> begin
      b_continue.Destroy(); 
      b_startNew.Destroy();
      b_rules.Destroy();
      b_about.Destroy();
      b_exit.Destroy();
    end;
    
    b_continue.OnClick := procedure() -> begin
      //Загружаем прогресс игрока
      ChangeLevel(loader.GetValue&<string>('$.current_level'));
      delButtons();
      LAGD.backgroundPic.Destroy();
    end;
    
    b_startNew.OnClick := procedure() -> begin
      //Сбрасываем прогресс игрока
      DrawConfirmMenu('ВЫ УВЕРЕНЫ?', 
      procedure() -> begin
        loader.SetValue('$.current_level', 'Level_0');
        loader.SaveFile();
        ChangeLevel(loader.GetValue&<string>('$.current_level'));
        LAGD.backgroundPic.Destroy();
      end, 
      procedure() -> begin
        DrawMainMenu();
      end);
      delButtons();
    end;
    
    b_rules.OnClick := procedure() -> begin DrawRulesMenu(); delButtons; end;
    b_about.OnClick := procedure() -> begin end;
    b_exit.OnClick := procedure() -> begin writeln('Игра закрыта!'); Halt; end;
  end;
  
  procedure StartGame();
  begin
    Window.Caption := 'Little Adventure';
    Window.IsFixedSize := True;
    Window.SetSize(1296, 768);
    Window.CenterOnScreen();
    LAGD.backgroundPic := new PictureWPF(0,0, 'data\levels\LALevels\png\MainMenuField.png');   
    //Сначала СОЗДАЕМ кнопки. Только потом ПРИСВАИВАЕМ события!
    //Создаем изображение перехода между уровнями.
    if (LAGD.TransPic = nil) then LAGD.TransPic := new TransitionPic();
    DrawMainMenu();
  end;
end.