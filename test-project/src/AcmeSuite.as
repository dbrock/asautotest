package
{
  import org.asspec.basic.*;

  public class AcmeSuite extends AbstractSuite
  {
    override protected function populate() : void
    { add(AcmeSpecification); }
  }
}
