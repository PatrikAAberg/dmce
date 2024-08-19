exppatternlist = [r'.*-CallExpr\sHexnumber\s<.*\,.*>.*',
                  r'.*-CXXMemberCallExpr\sHexnumber\s<.*\,.*>.*',
                  r'.*-CXXNewExpr\sHexnumber\s<.*\,.*>.*',
                  r'.*-CXXDeleteExpr\sHexnumber\s<.*\,.*>.*',
                  r'.*-StaticAssertDecl\sHexnumber\s<.*\,.*>.*',
                  r'.*-ConditionalOperator\sHexnumber\s<.*\,.*>.*',
                  r'.*BinaryOperator Hexnumber <.*\,.*>.*\'\*\'.*',
                  r'.*BinaryOperator Hexnumber <.*\,.*>.*\'\/\'.*',
                  r'.*BinaryOperator Hexnumber <.*\,.*>.*\'\-\'.*',
                  r'.*BinaryOperator Hexnumber <.*\,.*>.*\'\+\'.*',
                  r'.*UnaryOperator Hexnumber <.*\,.*>.*\'\+\+\'.*',
                  r'.*UnaryOperator Hexnumber <.*\,.*>.*\'\-\-\'.*',
                  r'.*UnaryOperator Hexnumber <.*\,.*>.*\'bool\' prefix \'!\'.*',
                  r'.*BinaryOperator Hexnumber <.*\,.*>.*\'\&\'.*',
                  r'.*BinaryOperator Hexnumber <.*\,.*>.*\'\|\'.*',
                  r'.*BinaryOperator Hexnumber <.*\,.*>.*\'=\'.*',
                  r'.*BinaryOperator Hexnumber <.*\,.*>.*\'<\'.*',
                  r'.*BinaryOperator Hexnumber <.*\,.*>.*\'>\'.*',
                  r'.*BinaryOperator Hexnumber <.*\,.*>.*\'==\'.*',
                  r'.*BinaryOperator Hexnumber <.*\,.*>.*\'!=\'.*',
                  r'.*BinaryOperator Hexnumber <.*\,.*>.*\'>=\'.*',
                  r'.*BinaryOperator Hexnumber <.*\,.*>.*\'<=\'.*',
                  r'.*BinaryOperator Hexnumber <.*\,.*>.*\'\&\&\'.*',
                  r'.*BinaryOperator Hexnumber <.*\,.*>.*\'\|\|\'.*',
                  r'.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\+\=\'.*',
                  r'.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\-\=\'.*',
                  r'.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\*\=\'.*',
                  r'.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\/\=\'.*',
                  r'.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\%\=\'.*',
                  r'.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\&\=\'.*',
                  r'.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\|\=\'.*',
                  r'.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\^\=\'.*',
                  r'.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\<<\=\'.*',
                  r'.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\>>\=\'.*',
                  r'.*ReturnStmt Hexnumber <.*\,.*>.*']

# Modes:
#  1    Contained space, use as is
#  2    Free, need to look for next
#  3    Free, look for next, use do-while instead of comma notation. If we need to probe certain statements (as opposed to expressions)
#  x    Free, look for next at colpos + x
exppatternmode = [2,2,2,2,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,3]
