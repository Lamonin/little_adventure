unit LAEngine;
{$reference Newtonsoft.Json.dll}
uses Newtonsoft.Json.Linq;
uses GraphWPF, WPFObjects, Timers;

///Проверяет - принадлежит ли точка прямоугольнику объекта
function PtInside(x,y:real; obj:ObjectWPF):boolean;
begin
  if (x>obj.LeftTop.X) and (x<obj.RightTop.X) and (y>obj.LeftTop.Y) and (y<obj.RightBottom.Y) then
  Result:=True;
end;

procedure CombatField();
 forward;

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
    idlePic, clickPic:string;
    
    ///Изменение спрайта на clickPic
    procedure Clicked(x, y: real; mousebutton: integer);
    begin
      if (mousebutton <> 1) then exit;
      if PtInside(x,y,pic) then 
      begin
        var t := pic;
        pic := new PictureWPF(t.LeftTop, clickPic);
        t.Destroy();
      end;
    end;
    
    ///Обработка нажатия
    procedure Process(x, y: real; mousebutton: integer);
    begin
      var t := pic;
      pic := new PictureWPF(t.LeftTop, idlePic);
      t.Destroy();
      if (mousebutton <> 0) then exit;
      
      if (OnClick <> nil) and PtInside(x,y,pic) then begin
        OnClick();
      end;
    end;
    
    public
    event OnClick: procedure; //Событие нажатия на кнопку
    
    ///Создаем кнопку с изображением по умолчанию idlePic
    ///И с изображением по нажатию clickPic.
    constructor Create(x,y:integer; idlePic, clickPic:string);
    begin
      self.idlePic := idlePic;
      self.clickPic := clickPic;
      pic := new PictureWPF(x, y, idlePic);
      OnMouseDown += Clicked;
      OnMouseUp += Process;
    end;
    
    procedure Destroy();
    begin
      pic.Destroy();
      OnMouseDown -= Clicked;
      OnMouseUp -= Process;
    end;
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
    defaultAnim:string; //Имя стандартной анимации
    curAnim:spriteInfo; //Текущая анимация
    sprite:PictureWPF;
    position:Point;
    
    updater:Timer;
    frameNum:Integer; //Номер текущего кадра анимации
    
    procedure ChangeSprite();
    begin
      Redraw(procedure()-> begin
        var p := sprite.LeftTop;
        sprite.Destroy();
        sprite:= new PictureWPF(p, curAnim.frames[frameNum]);
      end);
    end;
    
    //Обновление кадра изображения
    procedure UpdateFrame();
    begin
      if (frameNum<curAnim.frames.Length-1) then frameNum+=1
      else if curAnim.isLoop then frameNum:=0
      else begin updater.Stop(); exit; end;
      ChangeSprite();
    end;
    
    procedure SetPos(pos:Point);
    begin
      pos.Y -= 24;//Смещаем спрайт вверх, чтобы ногами был по центру тайла
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
    property Pos: Point write SetPos;
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
  //ОПИСАНИЕ ОБЩЕЙ ИНТЕРФЕЙСНОЙ ЧАСТИ
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
  
  levelGridArr = array[0..16, 0..26] of levelGridRecord;
  ///Общие данные игры по ходу её выполнения
  ///Обращение к данным делается, например, так: LAGD.Player
  LAGD = static class
    private
    static pplayer:IPlayerWorld;
    static llevelGrid:levelGridArr;
    static llevelPicture, CCombatPic:PictureWPF;
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
  end;
  //КОНЕЦ ОПИСАНИЯ ОБЩЕЙ ИНТЕРФЕЙСНОЙ ЧАСТИ
  
  UseObject = class(IUseObject)
    private
    typeObject:string;
    static dialogBanner:RectangleWPF;
    messages:array of string;
    messageNum:integer;
    messageCount:integer;
    levelName:string;
    messageTimer:Timer;
    EnemyPoint:array of string;
    static enemyPoints:List<GPoint>;
    
    public 
    
    static constructor();
    begin
      enemyPoints := new List<Gpoint>();
    end;
    
    static function CalculateEnemyPoint():integer;
    var min:integer;
    begin
      min:= 100;
      if (enemyPoints.Count<=0) then exit;
        for var i:=0 to enemyPoints.Count-1 do 
          begin
     result:= Round(Sqrt((enemyPoints[i].x - LAGD.Player.GetX)**2 + (enemyPoints[i].y - LAGD.Player.GetY)**2));
      if (Result < Min) then
        Min := Result;
     end;
     Writeln(min);
    end;
    
    procedure CreateEnemyPoint(ArrayEnemy: array of string; X,Y: integer);
    begin
      typeObject := 'EnemyPoint';
      EnemyPoint := ArrayEnemy;
      var p : GPoint;
      P.X :=X;
      p.Y :=Y;
      enemyPoints.add(p);
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
        dialogBanner := new RectangleWPF(0,768-128,1296, 128, Colors.Blue);
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
    
    static function CalculateEnemyPoint():integer;
    begin
      
    end;
    
    ///Возвращает тип этого объекта
    property objType: string read typeObject;
    ///Возвращает название уровня на который ведет этот объект
    property NextLevelName: string read levelName;
  end;  
  

  
  ///Класс игрока в "мире".
  PlayerWorld = class (IPlayerWorld)
    private
    point, useRect:RectangleWPF; //Невидимое тело объекта
    position:record x,y:integer end;
    sprite:LSprite;
    moveTimer, updateSprite:Timer;
    dir:string;
    isUsing, blocked:boolean;
    
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
      useRect := new RectangleWPF(x*48+12, y*48, 24, 24, Colors.Blue);
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
        'message': begin
          isUsing := obj.NextMessage();
        end;
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
    property isBlocked: boolean read blocked write blocked;
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
        'TransitionMessage': begin
          var tt:= val[j]['fieldInstances'][0]['__value'].ToString();
          var p := new RectangleWPF(100, 100, 400, 100, Colors.Wheat);
          p.Text := tt;
          p.FontName := 'Promocyja';
          p.TextAlignment := Alignment.Center;
        end;
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
    var t : levelGridArr; //
    LAGD.Grid := t; // Обнуляем таким образом сетку уровня
  end;
  
  ///Меняет текущий уровень на уровень с именем lname
  procedure ChangeLevel(lname:string);
  begin
    CloseLevel();
    LoadLevel(lname);
  end;
  
  procedure MainMenu();
  begin
    
  end;
  
  procedure CombatField();
  begin
    LAGD.Player.isBlocked := true; //Блокируем управление игроком
    LAGD.CombatPic := new PictureWPF(0, 0,'data\levels\LALevels\png\CombatField.png');
    LAGD.Player.SetPos(8,16);
  end; 
  
end.