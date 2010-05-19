package
{
  import org.asspec.*;
  import org.asspec.basic.*;

  public class AcmeSuite extends AbstractSuite
    implements SizedTest
  {
    public function get size() : uint { return 2; }

    override protected function populate() : void
    { add(AcmeSpecification); }
  }
}
