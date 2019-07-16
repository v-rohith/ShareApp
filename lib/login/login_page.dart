import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shareapp/extras/helpers.dart';
import 'package:shareapp/main.dart';
import 'package:shareapp/pages/home_page.dart';
import 'package:shareapp/services/auth.dart';
import 'package:shareapp/services/const.dart';

class LoginPage extends StatefulWidget {
  static const routeName = '/loginPage';

  LoginPage({Key key, this.title, this.auth, this.onSignIn}) : super(key: key);

  final String title;
  final BaseAuth auth;
  final VoidCallback onSignIn;

  @override
  _LoginPageState createState() => new _LoginPageState();
}

//enum FormType { login, register }
enum FormMode { LOGIN, SIGNUP }

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final formKey = new GlobalKey<FormState>();

  String email;
  String password;
  String errorMessage;

  // Initial form is login form
  FormMode formMode = FormMode.LOGIN;
  bool isIos;
  bool isLoading;

  // for animation
  AnimationController logoController;
  Animation<double> logoAnimation;
  AnimationController contentController;
  Animation<double> contentAnimation;
  AnimationController slideController;
  Animation<double> slideAnimation;
  AnimationController textController;
  Animation<Offset> textAnimation;

  var pageController = PageController();

  @override
  void dispose() {
    logoController.dispose();
    contentController.dispose();
    slideController.dispose();
    textController.dispose();
    super.dispose();
  }

  // Check if form is valid before perform login or signup
  bool _validateAndSave() {
    final form = formKey.currentState;
    if (form.validate()) {
      form.save();
      return true;
    }
    return false;
  }

  // Perform login or signup
  void _validateAndSubmit() async {
    setState(() {
      errorMessage = "";
      isLoading = true;
    });
    if (_validateAndSave()) {
      String userId = "";
      try {
        if (formMode == FormMode.LOGIN) {
          userId = await widget.auth.signIn(email, password);
          print('Signed in: $userId');
        } else {
          userId = await widget.auth.createUser(email, password);
          print('Signed up user: $userId');
          widget.onSignIn();
        }
        setState(() {
          isLoading = false;
        });

        if (userId.length > 0 && userId != null && formMode == FormMode.LOGIN) {
          widget.onSignIn();
        }
      } catch (e) {
        print('Error: $e');
        setState(() {
          isLoading = false;
          if (isIos) {
            errorMessage = e.details;
          } else
            errorMessage = e.message;
        });
      }
    }
  }

  @override
  void initState() {
    errorMessage = "";
    isLoading = false;
    super.initState();

    timeDilation = 2.0; // 3.0
    logoController = AnimationController(
        duration: const Duration(milliseconds: 1000), vsync: this);
    logoAnimation = CurvedAnimation(
        parent: logoController, curve: Interval(0, 0.5, curve: Curves.easeIn));
    contentController = AnimationController(
        duration: const Duration(milliseconds: 1000), vsync: this);
    contentAnimation = CurvedAnimation(
        parent: contentController,
        curve: Interval(0.4, 1, curve: Curves.easeIn));
    slideController = new AnimationController(
        vsync: this, duration: Duration(milliseconds: 500));
    slideAnimation = CurvedAnimation(
        parent: slideController, curve: Interval(0, 1, curve: Curves.easeIn));
    textController = new AnimationController(
        vsync: this, duration: Duration(milliseconds: 500));
    textAnimation = Tween(
      begin: Offset(0.0, 0.0),
      end: Offset(0.2, 0.0),
    ).animate(
      CurvedAnimation(
        parent: textController,
        curve: Interval(0, 1, curve: Curves.fastOutSlowIn),
      ),
    );

    logoController.forward();
    contentController.forward();
    slideController.repeat(reverse: true);
    textController.repeat(reverse: true);
  }

  void _changeFormToSignUp() {
    //formKey.currentState.reset();
    errorMessage = "";
    setState(() {
      formMode = FormMode.SIGNUP;
    });
  }

  void _changeFormToLogin() {
    //formKey.currentState.reset();
    errorMessage = "";
    setState(() {
      formMode = FormMode.LOGIN;
    });
  }

  @override
  Widget build(BuildContext context) {
    isIos = Theme.of(context).platform == TargetPlatform.iOS;
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;

    _loginPage() {
      return Material(
        color: primaryColor,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [primaryColor, Colors.black],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
          ),
          child: Stack(children: <Widget>[
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                FadeTransition(opacity: logoAnimation, child: _showLogo(false)),
                FadeTransition(opacity: contentAnimation, child: showBody()),
            ],),
            Padding(
              padding: const EdgeInsets.only(top: 60.0, right: 25.0),
              child: Align(alignment: Alignment.topRight, 
                child: OutlineButton(
                  borderSide: BorderSide(color: Colors.pink),
                  onPressed: null,
                  child: Text('Sign In', style: new TextStyle(fontSize: 18.0, fontWeight: FontWeight.w400, fontStyle: FontStyle.italic,
                  color: Colors.white, fontFamily: 'Quicksand')),
                ),),
            ),
          ],),
        ),
      );
    }

    _getStartedPage() {
      return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [primaryColor, Colors.black],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              FadeTransition(opacity: logoAnimation, child: _showLogo(false)),
              AnimatedBuilder(
                animation: textController,
                builder: (BuildContext context, Widget child) {
                  return FractionalTranslation(
                      child: Text("Swipe To Get Started ⟹",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontFamily: appFont,
                              fontSize: h / 40)),
                      translation: textAnimation.value);
                },
              ),
            ],
          ));
    }

    _info1() {
      return Stack(
        children: <Widget>[
          Container(
            height: h,
            width: w,
            decoration: BoxDecoration(
              color: Colors.purple,
              gradient: LinearGradient(
                  colors: [Colors.black, primaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(height: 40.0,),
              Text("Search anything you need", style: TextStyle(fontSize: h / 45, fontFamily: appFont, color: Colors.white),),
              SizedBox(height: 10.0,),
              Container(
                alignment: Alignment.center,
                height: h / 1.2,
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: ClipRRect(
                  child: Image.asset('assets/search.png'),
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
            ],
          )
        ],
      );
    }

    _info2() {
      return Stack(
        children: <Widget>[
          Container(
            height: h,
            width: w,
            decoration: BoxDecoration(
              color: Colors.purple,
              gradient: LinearGradient(
                  colors: [primaryColor, Colors.black],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(height: 40.0,),
              Text("Request an item at your convenience", style: TextStyle(fontSize: h / 45, fontFamily: appFont, color: Colors.white),),
              SizedBox(height: 10.0,),
              Container(
                height: h / 1.2,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: ClipRRect(
                  child: Image.asset('assets/request.jpg'),
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
            ],
          )
        ],
      );
    }

    List<Widget> pages = [
      Material(child: _getStartedPage()),
      Material(child: _info1()),
      Material(child: _info2()),
      Material(child: _loginPage()),
    ];

    return Stack(
      children: <Widget>[
        PageView.builder(
            controller: pageController,
            itemCount: pages.length,
            itemBuilder: (context, index) {
              return pages[index];
            }),
        Positioned(
          bottom: 30,
          left: w / 3,
          right: w / 3,
          child: new DotsIndicator(
            controller: pageController,
            itemCount: pages.length,
            onPageSelected: (int page) {
              pageController.animateToPage(
                page,
                duration: const Duration(milliseconds: 300),
                curve: Curves.ease,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget showBody() {
    return new Form(
      key: formKey,
      child: new ListView(
        padding: EdgeInsets.all(0),
        shrinkWrap: true,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: FlatButton(
                child: Text('Sign Up',
                    style: new TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        fontFamily: 'Quicksand')),
                onPressed: null),
          ),
          SizedBox(height: 10.0,),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: FlatButton(
              child: Text('Try It Out',
                  style: new TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                      fontFamily: 'Quicksand')),
              onPressed: navToAnonHomePage,
            ),
          ),
          SizedBox(height: 20.0,),
          googleLogin(),
          ecSignIn(),
          /*
        Padding(
          padding: const EdgeInsets.only(left: 40.0),
          child: Column(
            children: <Widget>[
              showEmailInput(),
              SizedBox(height: 10.0,),
              showPasswordInput(),
            ],
          ),
        ),
        SizedBox(height: 30.0,),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: showPrimaryButton(),
        ),
        showSecondaryButton(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            googleLogin(),
            otherUserSignin(),
          ],
        ),
        showErrorMessage(),*/
        ],
      ),
    );
  }

  Widget showErrorMessage() {
    if (errorMessage.length > 0 && errorMessage != null) {
      return new Text(
        errorMessage,
        style: TextStyle(
            fontSize: 13.0,
            color: Colors.red,
            height: 1.0,
            fontWeight: FontWeight.w300),
      );
    } else {
      return new Container(
        height: 0.0,
      );
    }
  }

  Widget _showLogo(bordered) {
    double w = MediaQuery.of(context).size.width;

    return Column(
      children: <Widget>[
        SvgPicture.asset(
          bordered ? 'assets/Border.svg' : 'assets/Borderless.svg',
          width: w / 1.5,
          height: w / 1.5,
        ),
        Text(
          "S H A R E",
          style: TextStyle(
              fontFamily: 'Quicksand', color: Colors.white, fontSize: w / 18),
        ),
      ],
    );
  }

  void navToAnonHomePage() async {
    Navigator.pushNamed(
      context,
      HomePage.routeName,
      arguments: HomePageArgs(
        null,
        null,
        () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget showEmailInput() {
    return Container(
      height: 70,
      padding: EdgeInsets.only(left: 10.0),
      decoration: new BoxDecoration(
        border: Border(left: BorderSide(color: Colors.white, width: 3)),
      ),
      child: Center(
        child: new TextFormField(
          maxLines: 1,
          keyboardType: TextInputType.emailAddress,
          autofocus: false,
          decoration: new InputDecoration(
              hintStyle:
                  TextStyle(color: Colors.white54, fontFamily: 'Quicksand'),
              hintText: 'Email',
              border: InputBorder.none,
              icon: new Icon(
                Icons.mail,
                color: Colors.white,
              )),
          validator: (value) => value.isEmpty ? 'Email can\'t be empty' : null,
          onSaved: (value) => email = value,
        ),
      ),
    );
  }

  Widget showPasswordInput() {
    return Container(
      height: 70,
      padding: const EdgeInsets.only(left: 10),
      decoration: new BoxDecoration(
        border: Border(left: BorderSide(color: Colors.white, width: 3)),
      ),
      child: Center(
        child: new TextFormField(
          maxLines: 1,
          obscureText: true,
          autofocus: false,
          decoration: new InputDecoration(
              hintText: 'Password',
              border: InputBorder.none,
              hintStyle:
                  TextStyle(color: Colors.white54, fontFamily: 'Quicksand'),
              icon: new Icon(
                Icons.lock,
                color: Colors.white,
              )),
          validator: (value) =>
              value.isEmpty ? 'Password can\'t be empty' : null,
          onSaved: (value) => password = value,
        ),
      ),
    );
  }

  Widget showSecondaryButton() {
    return new FlatButton(
      child: formMode == FormMode.LOGIN
          ? new Text('Create an account',
              style: new TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  fontFamily: 'Quicksand'))
          : new Text('Have an account? Sign in',
              style: new TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  fontFamily: 'Quicksand')),
      onPressed:
          formMode == FormMode.LOGIN ? _changeFormToSignUp : _changeFormToLogin,
    );
  }

  Widget googleLogin() {
    return Container(
      height: 60.0,
      child: new FlatButton(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Sign in with   ',
                    style: new TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        fontFamily: 'Quicksand')),
            ClipOval(
              child: Image.asset('assets/google.jpg'),
            ),
          ],
        ),
        onPressed: () => initGoogleLogin(),
      ),
    );
  }

  Widget facebookLogin() {
    return new RaisedButton(
        child: Text("Login with Facebook"),
        onPressed: null // () => initFacebookLogin(),
        );
  }

  Widget ecSignIn() {
    return Container(
      height: 60.0,
      width: 60.0,
      child: FlatButton(
        onPressed: signInEC,
        child: Text(
          'Sign in as EC\n(TESTING ONLY)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void initGoogleLogin() async {
    try {
      String userId = await widget.auth.logInGoogle();

      setState(() {
        errorMessage = 'Signed In\n\nUser id: $userId';
      });
      widget.onSignIn();
    } catch (e) {
      setState(() {
        errorMessage = 'Sign In Error\n\n${e.toString()}';
      });
      print(e);
    }
  }

  void initFacebookLogin() async {
    try {
      String userId = await widget.auth.loginFB();

      setState(() {
        errorMessage = 'Signed In\n\nUser id: $userId';
      });
      widget.onSignIn();
    } catch (e) {
      setState(() {
        errorMessage = 'Sign In Error\n\n${e.toString()}';
      });
      print(e);
    }
  }

  Widget showPrimaryButton() {
    return SizedBox(
      height: 40.0,
      child: new RaisedButton(
        elevation: 2.0,
        shape: new RoundedRectangleBorder(
            borderRadius: new BorderRadius.circular(10.0)),
        color: Colors.white,
        child: formMode == FormMode.LOGIN
            ? new Text('Login',
                style: new TextStyle(
                    fontSize: 20.0,
                    color: Colors.black,
                    fontFamily: 'Quicksand'))
            : new Text('Create account',
                style: new TextStyle(
                    fontSize: 20.0,
                    color: Colors.black,
                    fontFamily: 'Quicksand')),
        onPressed: _validateAndSubmit,
      ),
    );
  }

  void signInEC() async {
    setState(() {
      errorMessage = "";
      isLoading = true;
    });

    String userId = "";
    try {
      if (formMode == FormMode.LOGIN) {
        userId = await widget.auth.signIn('e@c.com', '000000');
        print('Signed in: $userId');
      } else {
        userId = await widget.auth.createUser(email, password);
        print('Signed up user: $userId');
        widget.onSignIn();
      }
      setState(() {
        isLoading = false;
      });

      if (userId.length > 0 && userId != null && formMode == FormMode.LOGIN) {
        widget.onSignIn();
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        isLoading = false;
        if (isIos) {
          errorMessage = e.details;
        } else
          errorMessage = e.message;
      });
    }
  }
}
