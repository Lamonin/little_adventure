# Little Adventure
Little Adventure - a simple game made on PascalABC.NET
___
### Описание библиотек
1. [LAEngine](#LAEngine)
2. [Vector2]("Vector2")

### LAEngine.pas
<a name="LAEngine"></a>
Это модуль содержащий все основные переменные, методы, и функции игры.
1. **Movable** - класс реализующий логику движения объектов.
2. **Player** - наследуется от Movable. Реализует сущность "игрока".

### Vector2
Вспомогательная библиотека. Содержит единственный класс V2 - который реализует вектор на плоскости.  
V2 имеет следующие поля, свойства, процедуры и функции:
1. **x** - значение X координаты вектора.
2. **y** - значение Y координаты вектора.
3. **normalized** - возвращает вектор длины 1, совпадающий по направлению с исходным.
4. **magnitude** - возвращает длину вектора.
5. **posInt** - возвращает вектор с целочисленными значениями *(необходимость под вопросом)*.
