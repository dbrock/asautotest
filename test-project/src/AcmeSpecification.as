package
{
  import org.asspec.basic.*;
  import org.asspec.specification.*;

  public class AcmeSpecification extends AbstractSpecification
  {
    override protected function execute() : void
    {
      it("should add correctly", function () : void {
        specify(1 + 1).should.equal(2); });
      it("should subtract correctly", function () : void {
        specify(1 - 1).should.equal(0); });
    }
  }
}
