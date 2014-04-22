Bodger
======

Just for fun - modify ('bodge') Apex Code, using the Tooling API, from Apex!

Open the Bodger page:

![Before](http://metadaddy-sfdc.github.io/Bodger/Before.png)

Click on a class, wait a few seconds:

![After](http://metadaddy-sfdc.github.io/Bodger/After.png)

This is `Tester` before being bodged:

	public class Tester {
	}

And after:

	public class Tester  implements MyInterface {
	 public String myMethod() { return 'It worked!';} }

Bodger will quite happily bodge its own controller. Try it and see!