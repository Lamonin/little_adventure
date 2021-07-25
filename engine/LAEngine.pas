unit LAEngine;
{$reference Newtonsoft.Json.dll}
uses Newtonsoft.Json.Linq;
uses WPFObjects, Timers, Loader;

//Вспомогательные методы для работы с объектами
///Проверяет - принадлежит ли точка прямоугольнику объекта
function PtInside(x,y:real; obj:ObjectWPF):boolean;
begin
  if (x>obj.LeftTop.X) and (x<obj.RightTop.X) and (y>obj.LeftTop.Y) and (y<obj.RightBottom.Y) then
  Result:=True;
end;

///Меняет изображение from на изображение из файла по пути too.
procedure ChangePicture(var from:PictureWPF; too:string);
begin
  var p := from; from := new PictureWPF(p.LeftTop, too); p.Destroy();
end;

function ApplyFontSettings(const obj:ObjectWPF):ObjectWPF;
begin
  obj.FontName := 'GranaPadano'; obj.FontColor := ARGB(255, 255, 214, 0);
  obj.FontSize := 32; obj.TextAlignment := Alignment.Center; Result := obj;
end;
//---------------------------------------------

//Опережающее описание процедур
procedure CloseLevel(); forward;
procedure ChangeLevel(lname:string); forward;
procedure DrawMainMenu(); forward;
procedure DrawConfirmMenu(text:string; confirm, cancel:procedure); forward;

type
  ///Получение и изменение значений в файле JSON формата.
  LALoader = class
    private
    path:string; jObj:JObject; //Хранит весь наш файл для дальнейшней работы с ним
    public
    ///Говорим "обрабатывать" файл с JSON структурой по пути path
    constructor Create(path:string);
    begin
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
    procedure SaveFile() := WriteAllText(path, jObj.ToString(), Encoding.UTF8);
  end;
  
  //##############-НАЧАЛО_ИНТЕРФЕЙС-################
  ///Пример использования:
  ///var b:= new LAButton(100, 200, 'img/ui/play.png', 'img/ui/playpress.png');
  ///b.OnClick += procedure() -> begin КОД КОТОРЫЙ ВЫПОЛНИТСЯ ПРИ НАЖАТИИ КНОПКИ end;
  LAButton = class
    private
    pic:PictureWPF; isClicked:boolean;
    idlePic, clickPic, buttonText:string;
    
    ///Изменение спрайта на clickPic
    procedure Clicked(x, y: real; mousebutton: integer);
    begin
      if (pic = nil) then exit;
      if (mousebutton <> 1) and (isClicked) then exit;
      if PtInside(x,y,pic) then begin
        isClicked := True;
        ChangePicture(pic, clickPic); ApplyText();
      end;
    end;
    
    ///Обработка нажатия
    procedure Process(x, y: real; mousebutton: integer);
    begin
      if (pic = nil) then exit;
      ChangePicture(pic, idlePic);
      ApplyText();
      if (mousebutton <> 0) then exit;
      if (OnClick <> nil) and PtInside(x,y,pic) and (isClicked) then OnClick();
      isClicked := False;
    end;
    
    procedure ApplyText();
    begin
      if (buttonText = '') or (pic = nil) then exit;
      pic.Text := buttonText;
      pic := ApplyFontSettings(pic) as PictureWPF;
    end;
    
    procedure SetText(t:string);
    begin
      buttonText := t; ApplyText();
    end;
    
    public
     //Событие нажатия на кнопку
    event OnClick: procedure;
    ///Создаем кнопку с изображением по умолчанию idlePic
    ///И с изображением по нажатию clickPic.
    constructor Create(x,y:integer; idlePic, clickPic:string);
    begin
      self.idlePic := 'img\ui\' + idlePic;
      self.clickPic := 'img\ui\' + clickPic;
      
      pic := new PictureWPF(x, y, self.idlePic);
      OnMouseDown += Clicked; OnMouseUp += Process;
    end;
    
    procedure Destroy();
    begin
      OnMouseDown -= Clicked; OnMouseUp -= Process;
      if (pic = nil) then exit;
      pic.Destroy(); pic := nil;
    end;
    
    property Text: string read buttonText write SetText;
  end;
  //##############-КОНЕЦ_ИНТЕРФЕЙС-#################
  
  //##############-НАЧАЛО_СПРАЙТЫ-################
  spriteInfo=record
    frames:array of string; //Кадры анимации.
    speed:integer; //Скорость анимации.
    isLoop:boolean; //Зациклена ли анимация.
    AnimProcedure:procedure; //Имеет смысл только если анимация не зациклена.
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
        sprite.Destroy();
        sprite:= new PictureWPF(0,0, curAnim.frames[frameNum]);
        SetPos(position);
        sprite.Visible := isVisible;
      end);
    end;
    
    //Обновление кадра изображения
    procedure UpdateFrame();
    begin
      if (frameNum<curAnim.frames.Length-1) then frameNum+=1
      else if curAnim.isLoop then frameNum:=0
      else begin 
        updater.Stop(); 
        if (curAnim.AnimProcedure<>nil) then curAnim.AnimProcedure;
        exit;
      end;
      ChangeSprite();
    end;
    
    function GetPos():Point;
    begin
      if (sprite <> nil) then Result := sprite.Center
      else Result := position;
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
      updater := new Timer(100, UpdateFrame);
      SetPos(position);
    end;
   
    ///Принадлежит ли точка спрайту
    function PtInside(x,y:Real):boolean;
    begin
      result := LAEngine.PtInside(X,Y,sprite);
    end;
    
    ///Добавляет новую анимацию с именем aname
    procedure AddAnim(aname:string; frames:array of string; speed:integer; looped:boolean; AnimProcedure:procedure:=nil);
    begin
      var frame:spriteInfo;
      frame.frames:= frames; frame.speed:=speed; frame.isLoop:=looped; frame.AnimProcedure:= AnimProcedure;
      anims.Add(aname, frame);
    end;
    
    ///Проигрывает анимацию с именем aname
    procedure PlayAnim(aname:string);
    begin
      curAnim := anims[aname];
      if (updater.Enabled) then updater.Stop();
      frameNum := 0;
      if (curAnim.frames.Length>1) then begin
        updater.Interval := curAnim.speed;
        updater.Start();
      end;
      ChangeSprite();
    end;
    
    ///Уничтожаем спрайт.
    procedure Destroy();
    begin
      updater.Stop();
      sprite.Destroy();
      sprite := nil;
    end;
    
    ///Устанавливает позицию спрайта
    property Pos: Point Read GetPos write SetPos;
    ///Количество фреймов текущей анимации
    property CurrentFrameCount: Integer Read GetFrameCount;
    ///Видимость спрайта
    property Visible: boolean write isVisible read isVisible;
    property Width: integer read floor(sprite.Width);
    property Height: integer read floor(sprite.Height);
  end;
  
  ///Загружает спрайт с именем sname.
  function LoadSprite(sname:string):array of string;
  begin
    Result := new string[1]; Result[0] := 'img/'+sname+'.png';
  end;
  
  ///Загружает последовательность спрайтов с именем sname и номерами от 1 до count.
  function LoadSprites(sname:string; count:integer):array of string;
  begin
    Result := new string[count];
    for var i:= 0 to count-1 do Result[i] := 'img/'+sname+(i+1)+'.png';
  end;
  //##############-КОНЕЦ_СПРАЙТЫ-################
  
  type
  pp = procedure;
  //ОПИСАНИЕ ИНТЕРФЕЙСНОЙ ЧАСТИ
  ITransitionPic = interface
    procedure Show( p:pp:=nil; delay:integer:=-1);
    procedure Show(message:string; delay:integer:=-1; p:pp:=nil);
    procedure Hide();
    procedure ToFront();
    property CanHide:boolean read;
  end;

  IUseObject = interface
    procedure Use();
    procedure Destroy();
  end;
  
  IPlayerWorld = interface
    procedure SetPos(x,y:integer);
    procedure MoveOn(x,y:integer; dir:string);
    procedure UseGrid();
    procedure Destroy();
    property OnMoveEvent:pp read write;
    property OnEnterBattleEvent: pp read write;
    property GetX: integer read;
    property GetY: integer read;
    property isBlocked: boolean read write;
    property SetUsing: boolean write;

  end;

  IDialogHandler = interface
    procedure StartDialog(messages:array of string);
    function NextMessage():boolean;
  end;
  
  levelGridRecord = record
    CantGet:boolean; //Можно ли ступить на клетку
    GridObject:IUseObject; //Объект на клетке
  end;
  
  levelGridArr = array[0..15, 0..26] of levelGridRecord;
  
  ///Общие данные игры по ходу её выполнения
  ///Обращение к данным делается, например, так: LAGD.Player
  LAGD = static class
    public
    static Player:IPlayerWorld; //Игрок в мире
    static Grid:levelGridArr; //Сетка уровня
    static LevelPic, CombatPic, BgPic:PictureWPF; //Изображения уровня, поля битвы и заднего фона меню
    static TransPic:ITransitionPic; //Экран перехода
    static DialogHandler:IDialogHandler;
  end;
  
  IBattleEntity = interface
    procedure Destroy();
    procedure Damage(Dmg: integer);
    procedure Attack();
    function AddAction():boolean;
    property GetDelay: integer Read;
    property GetDeath: boolean Read;
  end;
  
  IEnemy = interface (IBattleEntity)
    procedure Select();
    procedure Deselect();
    property GetName:string read;
    property GetCirclePic: PictureWPF read;
    property SetLockThis: boolean write;
  end;
  
  IBattlePlayer = interface (IBattleEntity)
    procedure AddHP(val:integer);
    property GetHP: integer Read;
    property GetMaxHP: integer Read;
    property GetDamage: integer Read;
    property SetArmor: integer Read Write;
  end;
  
  //КОНЕЦ ОПИСАНИЯ ИНТЕРФЕЙСНОЙ ЧАСТИ

  BattleEntity = class (IBattleEntity)
    private
    hp, attackDmg, agility, actionPoint, delay : integer;
    isDeath:boolean;
    public
    constructor Create(); begin end;
     
    function AddAction():boolean;
    begin
      if isDeath then exit;
      actionPoint+= agility;
      if actionPoint >=10 then 
      begin
        actionPoint-=10;
        result:= True;
      end;
    end;
    
    procedure Destroy(); virtual; begin end;
    procedure Damage(Dmg: integer);virtual; begin end;
    procedure Attack();virtual; begin end;
    
    property GetDelay: integer Read delay;
    property GetDeath: boolean Read isDeath;
  end;

  BattleProcessor = class
    private
    static ProcessTimer: Timer;
    static Stoptimer, isPlayerTurn: boolean;
    static BattleEnemyPanel, PlayerDamagePanel, PlayerArmorPanel, PlayerHPPanel, TurnRect : PictureWPF;
    static b_attack, b_run: LAButton;

    //Обработка очереди действий сущностей
    static procedure ProcessAttack(ActionList: List<IBattleEntity>);
    begin
    var I:= 0;
    ProcessTimer := new Timer(100,procedure() -> begin 
      if isPlayerTurn then exit;
      if I = ActionList.Count then begin
        ProcessTimer.Stop;
        Stoptimer:=False;
        exit;
      end;
      ProcessTimer.Interval:= ActionList[I].GetDelay;
      //Ходит игрок
      if ActionList[I] is IBattlePlayer then begin 
        isPlayerTurn:= True; 
        TurnRect.Text := 'ВАШ ХОД';
        I+=1;
        exit; 
      end;
      TurnRect.Text := 'ХОД ПРОТИВНИКА';
      ActionList[I].Attack();
      I+=1;
     end);
     ProcessTimer.Start;
    end;

    public
    static CombatTimer: Timer;
    static EnemyList: List<IEnemy>;
    static PlayerBattle: IBattlePlayer;
    static SelectedEnemy: IEnemy;
    static OnBattleEndEvent: procedure;
    static enemyCount:integer;

    static procedure EndBattle(Res:string);
    begin
      CombatTimer.Stop(); ProcessTimer.Stop(); Stoptimer := False; PlayerStep := False;
      if (Res <> 'Run') then begin
        LAGD.Grid[LAGD.Player.GetY, LAGD.Player.GetX].GridObject.Destroy();
        LAGD.Grid[LAGD.Player.GetY, LAGD.Player.GetX].GridObject := nil;
      end;
      var t:Timer;
      //Таймер выступает в роли задержки перед выходом из боя
      t := new Timer(1250, procedure() -> begin
        if (Res = 'Win') then //Игрок победил
        begin
          LAGD.TransPic.Show('ПОБЕДА', 1000, procedure() -> begin 
            LAGD.Player.isBlocked := False; 
          end);
        end
        else if (Res = 'Lose') then begin //Иначе проиграл
          LAGD.TransPic.Show('ПОРАЖЕНИЕ', 1000, procedure() -> begin
            CloseLevel();
            LAGD.Player.OnEnterBattleEvent := nil;
            LAGD.Player.Destroy();
            LAGD.Player := nil;
            LAGD.BgPic.Visible := True;
            BattleProcessor.PlayerBattle := nil;
            DrawMainMenu();
          end);
        end
        else if (Res = 'Run') then begin
          LAGD.TransPic.Show('ВЫ СБЕЖАЛИ', 1000, procedure() -> begin 
            LAGD.Player.isBlocked := False;

          end);
        end;
        //Удаляем интерфейс, сбрасываем параметры
        b_attack.Destroy(); b_run.Destroy();
        BattleEnemyPanel.Destroy(); PlayerDamagePanel.Destroy(); PlayerArmorPanel.Destroy();
        PlayerHPPanel.Destroy(); TurnRect.Destroy();

        foreach var tc in EnemyList do begin tc.Destroy(); end; // Уничтожаем врагов
        EnemyList.Clear();
        OnBattleEndEvent := nil; SelectedEnemy := nil; enemyCount := 0;

        LAGD.CombatPic.Destroy();
        t.Stop();
      end);
      t.Start();
    end;

    static procedure StartBattle();
      begin
      //Инициализируем элементы интерфейса боя
      b_attack:= new LAButton(167, 692, 'rect_button_battle.png', 'rect_button_battle_click.png');
      b_attack.Text := 'АТАКА';
      b_attack.OnClick += procedure() -> begin
        if (BattleProcessor.PlayerStep) and (BattleProcessor.SelectedEnemy<> nil) then
        begin BattleProcessor.PlayerStep:= False;
          BattleProcessor.PlayerBattle.Attack();
          BattleProcessor.SelectedEnemy.Deselect();
        end;
      end;

      b_run:= new LAButton(656, 692, 'rect_button_battle.png', 'rect_button_battle_click.png');
      b_run.Text := 'ПОБЕГ';
      b_run.OnClick += procedure() -> begin
        BattleProcessor.EndBattle('Run')
      end;
      
      TurnRect := new PictureWPF(327, 572, 'img\ui\rect_battle_turn.png');
      TurnRect := ApplyFontSettings(TurnRect) as PictureWPF;
      TurnRect.FontSize := 28;
      
      BattleEnemyPanel:= new PictureWPF(167, 616, 'img\ui\rect_panel_battle.png');
      BattleEnemyPanel := ApplyFontSettings(BattleEnemyPanel) as PictureWPF;

      foreach var t in EnemyList do BattleEnemyPanel.Text += t.GetName + '  |  ';
      BattleEnemyPanel.Text :=  Copy(BattleEnemyPanel.Text, 1, BattleEnemyPanel.Text.Length - 5);
      
      PlayerHPPanel := new PictureWPF(167, 572, 'img\ui\hp_bar.png');
      PlayerArmorPanel := new PictureWPF(936, 572, 'img\ui\rect_battle_mini.png');
      PlayerDamagePanel := new PictureWPF(1041, 572, 'img\ui\rect_battle_mini.png');
      var icon := new PictureWPF(0,0,'img\ui\icon_hp.png');
      PlayerHPPanel.AddChild(icon, Alignment.LeftTop);
      PlayerHPPanel := ApplyFontSettings(PlayerHPPanel) as PictureWPF;
      BattleProcessor.PlayerHPPanel.Text := PlayerBattle.GetHP +'/'+PlayerBattle.GetMaxHP;
      
      icon := new PictureWPF(0,0,'img\ui\icon_armor.png');
      PlayerArmorPanel.AddChild(icon, Alignment.LeftTop);
      PlayerArmorPanel := ApplyFontSettings(PlayerArmorPanel) as PictureWPF;
      PlayerArmorPanel.Text := PlayerBattle.SetArmor.ToString();

      icon := new PictureWPF(0,0,'img\ui\icon_damage.png');
      PlayerDamagePanel.AddChild(icon, Alignment.LeftTop);
      PlayerDamagePanel := ApplyFontSettings(PlayerDamagePanel) as PictureWPF;
      PlayerDamagePanel.Text := PlayerBattle.GetDamage.ToString();
      //Закончили инициализацию интерфейса

      CombatTimer := new Timer(250, procedure() ->
      begin
        if (StopTimer) then exit;
        if (enemyCount <= 0) then EndBattle('Win'); 
        var ActionList:= new List<IBattleEntity>();
        foreach var t in EnemyList do if t.AddAction() then ActionList.Add(t);                 
        if PlayerBattle.AddAction() then ActionList.Add(PlayerBattle);
        if (ActionList.Count>0) then
        begin       
          Stoptimer:= True;
          ProcessAttack(ActionList);
        end;
        end);
      end;
    static property PBattleEnemyPanel: PictureWPF read BattleEnemyPanel write BattleEnemyPanel;
    static property PlayerStep: boolean Read isPlayerTurn write isPlayerTurn;
  end;

  Enemy = class(BattleEntity, IEnemy)
    private
    name:string;
    Sprite : LSprite;
    LockThis, isDeath: boolean; //Выбран ли этот враг
    CirclePic, ShadowPic: PictureWPF; //Круг выделения и тень
    ///Нажатие на врага в бою
    procedure klik(x, y: real; mousebutton: integer);
    begin
      if (Sprite <> nil) and (mousebutton=1) and (Sprite.PtInside(x,y)) and not (LockThis) then 
      begin
        Select();
      end;
    end;

    procedure Death();
    begin
      isDeath := True;
      BattleProcessor.enemyCount -= 1;
      OnMouseDown -= klik;
      Sprite.PlayAnim('Death');
    end;
    
    function GetCircle():PictureWPF;
    begin
      if (CirclePic<>nil) then Result := CirclePic;
    end;

    public
    constructor Create(x,y:integer);
    begin
      BattleProcessor.OnBattleEndEvent += procedure -> Destroy();
      BattleProcessor.enemyCount += 1;
      OnMouseDown += klik;
    end;

    procedure CreateCircleShadowPics(yOffset:integer);
    begin
      ShadowPic := new PictureWPF(Sprite.Pos.X-65, Sprite.Pos.Y+Sprite.Height/2-yOffset, 'img\enemy\shadow.png');
      CirclePic:= new PictureWPF(Sprite.Pos.X-65,Sprite.Pos.Y+Sprite.Height/2-45,'img\enemy\circle.png');
      CirclePic.Visible := False;
    end;

    procedure Select();
    begin
      if (BattleProcessor.SelectedEnemy<>nil) then 
        BattleProcessor.SelectedEnemy.Deselect();
      CirclePic.Visible := True;
      LockThis:= True;
      BattleProcessor.SelectedEnemy:= self;
    end;

    procedure Deselect();
    begin
      BattleProcessor.SelectedEnemy.GetCirclePic.Visible := False;    
      BattleProcessor.SelectedEnemy.SetLockThis:= False;
      BattleProcessor.SelectedEnemy := nil;
    end;

    procedure Attack(); override;      
    begin
      if (isDeath) or (BattleProcessor.PlayerBattle.GetHP <= 0) then exit;
      BattleProcessor.PlayerBattle.Damage(attackDmg);
      Sprite.PlayAnim('Attack');
    end;
    
    procedure Damage(Dmg: integer); override;
    begin
      hp -= Dmg;
      if (hp<=0) then Death() else Sprite.PlayAnim('Hit');
    end;

    procedure Destroy(); override;
    begin
      if (Sprite<>nil) then Sprite.Destroy(); Sprite := nil;
      if (ShadowPic<>nil) then ShadowPic.Destroy(); ShadowPic := nil;
      if (CirclePic<>nil) then CirclePic.Destroy(); CirclePic := nil;
    end;
    
    property GetName: string read name;
    property GetCirclePic: PictureWPF read GetCircle;
    property SetLockThis: boolean write LockThis;
    end;
  
  SkeletonEnemy = class(Enemy)
    public
    constructor Create(x, y:integer);
    begin
      inherited Create(x,y);
      name := 'СКЕЛЕТОН';
      hp:= 9;
      attackDmg:=25;
      agility:=3;
      Delay:= 2000;
      Sprite:= new LSprite(x,y,'Idle',LoadSprites('enemy\Skeleton_Seeker\idle', 6));
      Sprite.AddAnim('Hit', LoadSprites('enemy\Skeleton_Seeker\hit', 4), 160, False, procedure()->
      begin
        sprite.PlayAnim('Idle'); 
      end);
      Sprite.AddAnim('Attack', LoadSprites('enemy\Skeleton_Seeker\attack', 10), 160, False, procedure()->
      begin
      sprite.PlayAnim('Idle'); 
      end);
      Sprite.AddAnim('Death', LoadSprites('enemy\Skeleton_Seeker\death', 5), 160, False);
      Sprite.PlayAnim('Idle');
      CreateCircleShadowPics(40);
    end;
    end;
  
  TreeEnemy = class(Enemy)
    public
    constructor Create(x, y:integer);
    begin
      inherited Create(x,y);
      name := 'ДРЕВО';
      attackDmg:=4;
      agility:=2;
      hp:=15;
      Delay:= 2000;
      Sprite:= new LSprite(x,y,'Idle',LoadSprites('enemy\Sprout\idle', 4));
      Sprite.AddAnim('Hit', LoadSprites('enemy\Sprout\hit', 5), 160, False, procedure()->
      begin
        sprite.PlayAnim('Idle'); 
      end);
      Sprite.AddAnim('Attack', LoadSprites('enemy\Sprout\attack', 6), 160, False, procedure()->begin
        Sprite.PlayAnim('Idle'); 
      end);
      Sprite.AddAnim('Death', LoadSprites('enemy\Sprout\death', 8), 160, False);
      Sprite.PlayAnim('Idle');
      CreateCircleShadowPics(45);
    end;
    end;
  
  GolemEnemy = class(Enemy)
    public
    constructor Create(x, y:integer);
    begin
      inherited Create(x,y);
      name := 'ГОЛЕМ <БОСС>';
      attackDmg:=10;
      agility:=8;
      hp:=30;
      Delay:= 2000;
      Sprite:= new LSprite(x, y, 'Idle', LoadSprites('enemy\Golem\idle', 6));
      Sprite.AddAnim('Hit', LoadSprites('enemy\Golem\hit', 4), 160, False, procedure()->
      begin
        sprite.PlayAnim('Idle');
      end);
      Sprite.AddAnim('Attack', LoadSprites('enemy\Golem\attack', 8), 160, False, procedure()->begin
        Sprite.PlayAnim('Idle');
      end);
      Sprite.AddAnim('Death', LoadSprites('enemy\Golem\death', 10), 160, False);
      Sprite.PlayAnim('Idle');
      CreateCircleShadowPics(45);
    end;
    end;
  
  BattlePlayer = class(BattleEntity, IBattlePlayer)
    private
    max_hp, armor:integer; //Максимальное здоровье игрока
    procedure Death();
    begin
      Writeln('Игрок проиграл');
      BattleProcessor.EndBattle('Lose');
    end;
    public
    constructor Create();
    begin
      var loader := new LALoader('data/userdata.json');
      //loader.GetValue&<integer>('$.hp');
      max_hp:= 20;
      hp:= max_hp;
      attackDmg:= 8;
      agility:= 5;
      Delay:= 250;
    end;
    
    procedure Attack();override;      
    begin
      if (BattleProcessor.SelectedEnemy = nil) then exit; 
      BattleProcessor.SelectedEnemy.Damage(AttackDmg);
    end;

    procedure AddHP(val:integer);
    begin
      hp += val;
      if hp>max_hp then hp := max_hp;
    end;
        
    procedure Damage(Dmg: integer);override;
    begin
      Dmg -= armor; if Dmg<=0 then Dmg := 1;
      hp -= Dmg;
      if (hp<=0) then begin
        hp := 0;
        BattleProcessor.PlayerHPPanel.Text := hp +'/'+max_hp;
        Death(); exit;
      end;
      BattleProcessor.PlayerHPPanel.Text := hp +'/'+max_hp;
    end;
    
    property GetHP: integer Read hp;
    property GetMaxHP: integer Read max_hp;
    property GetDamage: integer Read attackDmg;
    property SetArmor: integer Read armor Write armor;
    end;
  
  
  DialogHandler = class(IDialogHandler)
    private
    messages : array of string;
    messageNum, messageCount:integer; //Текущий номер сообщения и текущий символ сообщения
    messageTimer:Timer;
    dialogRect:PictureWPF;
    isDialogue: boolean; //Идёт ли диалог
    procedure EndDialogue();
    begin
      LAGD.Player.SetUsing := False;
      dialogRect.Visible := False;
      messageTimer.Stop();
      isDialogue := False;
    end;
    public
    constructor Create();
    begin
      if (dialogRect = nil) then Redraw(procedure() -> begin
        dialogRect := new PictureWPF(0,768-128,'img\ui\rect_game_big.png');
        dialogRect := ApplyFontSettings(dialogRect) as PictureWPF;
        dialogRect.FontSize := 24;
        dialogRect.Visible := False;
      end);
      messageTimer := new Timer(16, procedure() -> begin
        dialogRect.Text += messages[messageNum][messageCount];
        if (messageCount = messages[messageNum].Length) then
          messageTimer.Stop();
        messageCount += 1;
      end);
    end;

    procedure StartDialog(messages:array of string);
    begin
      dialogRect.ToFront();
      messageNum := -1; messageCount := 1;
      self.messages := messages; //Сохраняем сообщения
      dialogRect.Visible := True;
      LAGD.Player.SetUsing := True;
      isDialogue := True;
      NextMessage();
    end;

    function NextMessage():boolean;
    begin
      if not isDialogue then exit;
      Result:=True; //Диалог может продолжаться
      if (messageTimer.Enabled) then
      begin
        messageTimer.Stop(); dialogRect.Text := messages[messageNum]; exit;
      end;
      messageNum += 1;

      //Если показали все сообщения, то закрываем окно диалога.
      if (messageNum = messages.Length) then begin
        EndDialogue(); exit;
      end;
      //Начинаем с первого символа сообщения и пустого текста в окне сообщений
      messageCount := 1; dialogRect.Text := '';
      messageTimer.Start();
    end;
  end;
  
  UseObject = class(IUseObject)
    public
    procedure Use(); virtual; begin end;
    procedure Destroy(); virtual; begin end;
  end;
  
  MessageCell = class (UseObject)
    private
    messages : array of string;
    public
    constructor Create(messages:array of string);
    begin
      self.messages := messages;
    end;

    procedure Use(); override;
    begin
      if (LAGD.DialogHandler <> nil) then 
        LAGD.DialogHandler.StartDialog(messages);
    end;
    end;
  
  BattleCell = class (UseObject)
    private
    EnemyOnPoint:array of string; //Какие враги в этой точке
    x,y:integer;
    isCompleted:boolean; //Пройден ли бой в этой точке
    isInBattle:boolean; //В бою ли игрок
    ///Проверяет расстояния до игрока, включает видимость огня,
    ///если игрок рядом.
    procedure CheckPlayerDistance();
    begin
      if (ePointAnim = nil) or (isCompleted) then exit;
      //Сколько клеток до игрока
      var distance := Round(Sqrt((x - LAGD.Player.GetX)**2 + (y - LAGD.Player.GetY)**2));
      if (distance < 2) then ePointAnim.Visible := True else ePointAnim.Visible := False;
      
      if (LAGD.Player.GetX <> x) or (LAGD.Player.GetY <> y) then exit;
      
      //Начинаем бой, если игрок стоит на точке начала боя.
      LAGD.TransPic.Show('Начало боя', 1000, procedure -> begin 
        BattleProcessor.CombatTimer.Start; 
        LAGD.Player.OnEnterBattleEvent; end);
      LAGD.Player.isBlocked := True; //Блокируем управление игроком
      LAGD.CombatPic := new PictureWPF(0, 0,'data\levels\LALevels\png\CombatField.png');

      BattleProcessor.EnemyList:= new List<IEnemy>();
      for var i:= 0 to EnemyOnPoint.Length-1 do
        case (i+1) of
            1: CreateEnemy(i, 13, 5);
            2: CreateEnemy(i, 16, 3);
            3: CreateEnemy(i, 10, 3);
            4: CreateEnemy(i, 7, 5);
            5: CreateEnemy(i, 19, 5);
        end;
      BattleProcessor.StartBattle();
    end;

    procedure CreateEnemy(Index:integer; X,Y:integer);
    begin
      var E: IEnemy;
      case EnemyOnPoint[Index] of
        'Skeleton': E:= new SkeletonEnemy(X,Y);
        'TreeEnemy': E:= new TreeEnemy(X,Y);
        'Golem': E:= new GolemEnemy(X,Y);
      end;
      BattleProcessor.EnemyList.Add(E);
    end;

    public
    ePointAnim:LSprite;
    static battleCellCount:integer;

    constructor Create(x,y: integer; EnemyOnPoint: array of string);
    begin
      battleCellCount+=1;
      self.EnemyOnPoint := EnemyOnPoint;
      self.x := x; self.y := y;
      ePointAnim := new LSprite(x,y,'idle', LoadSprites('blue_fire',8));
      var p:Point; p.X := x*48; p.Y := y*48 + 16;
      ePointAnim.Pos := p; ePointAnim.Visible := False; ePointAnim.PlayAnim('idle');
      P.X := x; p.Y := y;
      LAGD.Player.OnMoveEvent += procedure -> CheckPlayerDistance();
      LAGD.Player.OnEnterBattleEvent += procedure -> if (ePointAnim <> nil) then ePointAnim.Visible := False;
    end;
    
    procedure Destroy(); override;
    begin 
      battleCellCount -= 1;
      isCompleted := True;
      ePointAnim.Destroy(); ePointAnim := nil;
      LAGD.Player.OnMoveEvent -= procedure -> CheckPlayerDistance();
      LAGD.Player.OnEnterBattleEvent -= procedure -> if (ePointAnim <> nil) then ePointAnim.Visible := False;
    end;
    end;

  NextLevelCell = class(UseObject)
    private
    levelName:string;
    public
    constructor Create(levelName:string);
    begin
      self.levelName := levelName;
    end;
    ///Переход на следующий уровень.
    procedure Use(); override;
    begin
      if BattleCell.battleCellCount > 0 then begin
        var messages:array of string := ('За моей спиной остались противники, я не могу быть небрежным!');
        LAGD.DialogHandler.StartDialog(messages);
      end
      else
        ChangeLevel(levelName);
    end;
    end;
  
  PickableCell = class (UseObject)
    private
    sprite: PictureWPF;
    isPickup: boolean; //Взаимодействовал ли персонаж игрока с объектом
    ///Происходит "подбор" объекта
    procedure Pickup(); virtual; begin isPickup := True; sprite.Destroy(); sprite := nil; end;

    public
    constructor Create(x,y:integer; path:string);
    begin
      sprite := new PictureWPF(x*48, y*48, path);
    end;
    procedure Use(); override; begin if not isPickup then Pickup(); end;
    
    procedure Destroy(); override;
    begin
      if sprite <> nil then sprite.Destroy();
      Writeln('Поднимаемый объект уничтожен!');
    end;
    end;
  
  PotionPickup = class (PickableCell)
    private
    potionPower:integer := 10;
    procedure Pickup(); override;
    begin
      inherited Pickup();
      BattleProcessor.PlayerBattle.AddHP(potionPower);
      var messages:array of string := ($'Вы восстановили {potionPower} маны.');
      LAGD.DialogHandler.StartDialog(messages);
    end;
    public
    constructor Create(x,y:integer);
    begin
      inherited Create(x,y, 'img/potion.png');
    end;
    end;

  ArmorPickup = class (PickableCell)
    private
    armorValue:integer := 10;
    procedure Pickup(); override;
    begin
      inherited Pickup();
      BattleProcessor.PlayerBattle.SetArmor := armorValue;
      var messages:array of string := ( $'Вы надели броню поглощающую {armorValue} ед. урона.');
      LAGD.DialogHandler.StartDialog(messages);
    end;
    public
    constructor Create(x,y:integer);
    begin
      inherited Create(x,y, 'img/armor.png');
    end;
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
    MoveEvent, InBattleEvent:pp;

    procedure Blocking(blocked:boolean);
    begin
      self.blocked := blocked;
      sprite.Visible := not blocked;
      if not blocked then
        sprite.PlayAnim('rotatedown');
    end;
    
    //Проверяет можно ли использовать клетку на которую смотрит персонаж,
    //или на которой он стоит.
    procedure CheckGridUse();
    begin
      useRect.Visible := False; //По умолчани делаем его False
      var obj := LAGD.Grid[GetY, GetX].GridObject;
      if (obj <> nil) then
        if (obj is NextLevelCell) then begin useRect.Visible := True; exit; end
        else if (obj is PickableCell) then begin obj.Use(); exit; end;
      
      var dx := 0; var dy := 0;
      case self.dir of 
        'left': dx := -1;
        'right': dx := 1;
        'up': dy := -1;
        'down': dy := 1;
      end;

      if (GetX+dx<0) or (GetX+dx>26) or (GetY+dy<0) or (GetY+dy>15) then exit;
      
      obj := LAGD.Grid[GetY+dy, GetX+dx].GridObject;
      if (obj<>nil) and (obj is MessageCell) then useRect.Visible := True;
    end;
    
    public
     //Заблокировано ли управление игроком
    constructor Create(x,y:integer);
    begin
      position.x := x; position.y := y;
      point := new RectangleWPF(x*48, y*48, 4, 4, Colors.Black);
      point.Visible := False;
      useRect := new PictureWPF(x*48+12, y*48, 'img\ui\rect_small.png');
      useRect.TextAlignment := Alignment.Center;
      useRect.FontColor := Colors.Yellow;
      useRect.FontSize := 18;
      useRect.FontName := 'GranaPadano'; useRect.Text := 'E';
      useRect.Visible := False;
      
      //Инициализация изображений игрока
      sprite := new LSprite(x, y, 'idledown', LoadSprite('player/down2'), 160, False);
      
      sprite.AddAnim('rotateleft', LoadSprite('player/left4'), 100, False);
      sprite.AddAnim('rotateright', LoadSprite('player/right4'), 100, False);
      sprite.AddAnim('rotateup', LoadSprite('player/up2'), 100, False);
      sprite.AddAnim('rotatedown', LoadSprite('player/down2'), 100, False);
      
      sprite.AddAnim('walkleft', LoadSprites('player/left', 4), 160, False);
      sprite.AddAnim('walkright', LoadSprites('player/right', 4), 160, False);
      sprite.AddAnim('walkup', LoadSprites('player/up', 4), 160, False);
      sprite.AddAnim('walkdown', LoadSprites('player/down', 4), 160, False);
      
      sprite.PlayAnim('idledown');
      //*************************
      
      //Обновляем позицию визуального представления игрока
      updateSprite := new Timer(10, procedure() -> begin
        var p := point.LeftTop;
        p.Y += 12;
        sprite.Pos := p;
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
      MoveEvent;
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
      else begin //Скорость игрока
        //Обрабатываем "поворот" и движение игрока, включая соответствующую анимацию
        sprite.PlayAnim('walk'+dir);
        position.x += x; position.y += y;
        point.AnimMoveTo(GetX*48, GetY*48, 0.2);
        
        //Таймер нужен чтобы игрок не двигался с бесконечным ускорением
        moveTimer := new Timer(200, procedure -> begin moveTimer.Stop(); MoveEvent; end);
        moveTimer.Start();
      end;
      CheckGridUse();   
    end;
      
    procedure UseGrid();
    begin
      if not useRect.Visible then exit;
      var obj := LAGD.Grid[GetY, GetX].GridObject;
      if (obj <> nil) and (obj is NextLevelCell) then begin
        obj.Use(); exit;
      end;
      
      var dx := 0; var dy := 0;
      case self.dir of
        'left': dx := -1;
        'right': dx := 1;
        'up': dy := -1;
        'down': dy := 1;
      end;
      //Если взаимодействуем с клеткой за границей экрана, то просто выходим.
      if (GetX+dx<0) or (GetX+dx>26) or (GetY+dy<0) or (GetY+dy>15) then exit;
      obj := LAGD.Grid[GetY+dy, GetX+dx].GridObject;
      if (obj<>nil) then obj.Use();
    end;
    
    ///Уничтожаем объект игрока.
    procedure Destroy();
    begin
      moveTimer.Stop(); updateSprite.Stop();
      point.Destroy();
      useRect.Destroy();
      sprite.Destroy();
    end;
    
    ///Событие окончания движения игрока
    property OnMoveEvent: pp read MoveEvent write MoveEvent;
    property OnEnterBattleEvent: pp read InBattleEvent write InBattleEvent;
    property GetX: integer read position.x;
    property GetY: integer read position.y;
    property isBlocked: boolean read blocked write Blocking;
    property SetUsing: boolean write isUsing;
  end;
  
  TransitionPic = class (ITransitionPic)
    private
    pic:RectangleWPF;
    isCanHide:boolean;
    proc:pp;
    public
    constructor Create;
    begin
      Redraw(procedure()-> begin
        pic := new RectangleWPF(0, 0, 1296, 768, Colors.Black);
        pic.FontName := 'GranaPadano';
        pic.FontColor := Colors.White;
        pic.FontSize := 32;
        pic.TextAlignment := Alignment.Center;
        pic.Visible := False;
      end);
      OnDrawFrame += procedure(dt:real) -> LAGD.TransPic.ToFront();
    end;
    
    ///Показать изображение перехода
    procedure Show(p:pp:=nil; delay:integer:=-1);
    begin
      Show('Для продолжения нажмите SPACE', delay, p);
    end;
    
    ///Показать изображение перехода с нужным текстом после загрузки
    procedure Show(message:string; delay:integer:=-1; p:pp:=nil);
    begin
      proc:=p;
      var t:Timer;
      if (LAGD.player <> nil) then
        LAGD.player.isBlocked := True; //Блокируем движение игрока
      
      if (delay <> -1) then begin
        Redraw(procedure()-> begin
          pic.Visible := True;
          pic.Text := message;
        end);
        t := new Timer(delay, procedure() -> begin
          Hide();
          t.Stop();
        end);
        t.Start(); exit;
      end;
      
      Redraw(procedure()-> begin
        pic.Visible := True;
        pic.Text := 'Загрузка уровня...';
      end);

      t := new Timer(1000, procedure() -> begin
        isCanHide := True;
        pic.Text := message;
        t.Stop();
      end); t.Start();
    end;
    
    ///Скрыть изображение перехода
    procedure Hide();
    begin
      if (proc<>nil) then proc;
      isCanHide := False;
      pic.Visible := False;
    end;
    
    procedure ToFront();
    begin if (pic <> nil) then pic.ToFront(); end;
    
    property CanHide:boolean read isCanHide;
  end;
  
  ///Загружает уровень с именем lname и настраивает сетку grid.
  procedure LoadLevel(lname:string);
  begin
    var loader := new LALoader('data/levels/LALevels.ldtk');
    LAGD.TransPic.Show(procedure()-> begin LAGD.Player.isBlocked := False end);
    var i := -1;
    
    //Находим номер уровня в массиве
    for i := 0 to loader.GetValue&<JToken>('$.levels').Count()-1 do
      if loader.GetValue&<string>('$.levels['+i+'].identifier') = lname then break;
    
    var val := loader.GetValue&<JToken>('$.levels['+i+'].layerInstances[0].entityInstances');
    var x,y:integer;
    if (LAGD.Player = nil) then LAGD.Player := new PlayerWorld(1,1);
    for var j:=0 to val.Count()-1 do begin
      x := Integer(val[j]['__grid'][0]);
      y := Integer(val[j]['__grid'][1]);
      var cell := LAGD.Grid[y,x];
      ///Определя
      case val[j]['__identifier'].ToString() of
        'Wall': cell.CantGet := True;
        'SpawnPoint': LAGD.Player.SetPos(x,y);
        'MessageObject': begin
          //Можно ли "наступить" на объект сообщения
          var vval := val[j]['fieldInstances'];
          if (vval[1]['__value'].ToString() = 'False') then cell.CantGet := True;
          cell.GridObject := new MessageCell(vval[0]['__value'].ToObject&<array of string>());
        end;
        'NextLevel': begin
          cell.GridObject := new NextLevelCell(val[j]['fieldInstances'][0]['__value'].ToString());
        end;
        'EnemyPoint': begin
          var tt:= val[j]['fieldInstances'][0]['__value'].ToObject&<array of string>();
          cell.GridObject := new BattleCell(x,y,tt);
        end;
        'Armor': cell.GridObject := new ArmorPickup(x,y);
        'Potion': cell.GridObject := new PotionPickup(x,y);
      end;
      LAGD.Grid[y,x] := cell;
    end;
    //Устанавливаем изображение уровня
    LAGD.LevelPic := new PictureWPF(0, 0,'data/levels/LALevels/png/'+lname+'.png');
    LAGD.LevelPic.ToBack(); //Перемещаем изображение уровня назад.
    
    if (BattleProcessor.PlayerBattle = nil) then 
        BattleProcessor.PlayerBattle:= new BattlePlayer;
  end;
  
  ///Закрывает текущий уровень
  procedure CloseLevel();
  begin
    if (LAGD.LevelPic = nil) then exit;
    LAGD.LevelPic.Destroy(); //Уничтожаем старое изображение уровня
    LAGD.LevelPic := nil;
    for var i := 0 to 15 do
      for var j:= 0 to 26 do begin
        if (LAGD.Grid[i,j].GridObject <> nil) then LAGD.Grid[i,j].GridObject.Destroy();
      end;
    var t : levelGridArr; //
    LAGD.Grid := t; // Обнуляем таким образом сетку уровня
  end;
  
  ///Меняет текущий уровень на уровень с именем lname
  procedure ChangeLevel(lname:string);
  begin
    CloseLevel();
    //Сохраняем прогресс игрока
    var loader := new LALoader('data/userdata.json');
    loader.SetValue('$.current_level', lname);
    if (BattleProcessor.PlayerBattle<> nil) then
      loader.SetValue('$.hp', BattleProcessor.PlayerBattle.GetHP);
    loader.SaveFile();
    LoadLevel(lname);
  end;
  
  //РАЗДЕЛ ОПИСАНИЯ ГЛАВНОГО МЕНЮ
  procedure DrawConfirmMenu(text:string; confirm, cancel:procedure);
  var b_confirm, b_cancel: LAButton;
  begin
    var r_body := new PictureWPF(384, 280, 'img\ui\rect_confirm.png');
    r_body.Text := text;
    r_body := ApplyFontSettings(r_body) as PictureWPF;

    b_confirm := new LAButton(384, 424, 'rect_menu_rules_wide.png', 'rect_menu_rules_wide_click.png');
    b_confirm.Text := 'ОК';
    b_cancel := new LAButton(656, 424, 'rect_menu_rules_wide.png', 'rect_menu_rules_wide_click.png');
    b_cancel.Text := 'ОТМЕНА';
    
    b_confirm.OnClick += procedure() -> begin 
      confirm; 
      r_body.Destroy(); b_confirm.Destroy(); b_cancel.Destroy(); 
    end;
    
    b_cancel.OnClick += procedure() -> begin
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
    
    b_back.OnClick += procedure() -> begin
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
    
    b_continue.OnClick += procedure() -> begin
      //Загружаем прогресс игрока
      ChangeLevel(loader.GetValue&<string>('$.current_level'));
      delButtons();
      LAGD.BgPic.Visible := False;
    end;
    
    b_startNew.OnClick += procedure() -> begin
      //Сбрасываем прогресс игрока
      DrawConfirmMenu('ВЫ УВЕРЕНЫ?', 
      procedure() -> begin
        loader.SetValue('$.current_level', 'Level_0');
        loader.SaveFile();
        ChangeLevel(loader.GetValue&<string>('$.current_level'));
        LAGD.BgPic.Visible := False;
      end, 
      procedure() -> begin
        DrawMainMenu();
      end);
      delButtons();
    end;
    
    b_rules.OnClick += procedure() -> begin DrawRulesMenu(); delButtons; end;
    b_about.OnClick += procedure() -> begin end;
    b_exit.OnClick += procedure() -> begin writeln('Игра закрыта!'); Halt; end;
  end;
  
  procedure StartGame();
  begin
    Window.Caption := 'Little Adventure';
    Window.IsFixedSize := True;
    Window.SetSize(1296, 768);
    Window.CenterOnScreen();

    LAGD.BgPic := new PictureWPF(0,0, 'img\MainMenuField1.png');   
    if (LAGD.TransPic = nil) then LAGD.TransPic := new TransitionPic();
    if (LAGD.DialogHandler = nil) then LAGD.DialogHandler := new DialogHandler();
    DrawMainMenu();
  end;
end.