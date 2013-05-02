//Can we model a moving object using Machinations?
MovingObject
{
  pool velocity of m/s at 2      //declare a pool velocity starting at 2 meters/second
  pool timeLeft of s at 5        //declare a pool timeLeft of s starting at 5 seconds
  pool timePassed of s at 0      //declare a pool timePassed of s starting at 0 seconds
  pool distance of m at 0        //declare a pool distance of m starting at 0 meters
  active pull all converter stepTime from s to m //for each second passing move
  timeLeft --> stepTime          //time passing requires time as input
  stepTime -velocity * 1s-> distance //time passing generates distance?
}

/*
public class MovingObject
{
  private real velocity;
  private real timeLeft;
  private real timePassed;
  private real distance;
  
  public MovingObject()
  {
    velocity = 2;
    timeLeft = 5;
    timePassed = 0;
    distance = 0;
  }
  
  public void stepTime()
  {
    //check if all conditions are met:
    //for each flow into stepTime
    //check the source contains the required amount
    
    //effect
    if(timeLeft > 0)
    {
      timeLeft--;
      distance+=2;
    }
  }
}
*/

/*
data Object = 
  object
  (
    ComponentType ct,
    ComponentTypeInfo cti,
    map[str, real] values    
  );
*/