exppatternlist = ['.*-CallExpr\sHexnumber\s<.*\,.*>.*',
                  '.*-CXXMemberCallExpr\sHexnumber\s<.*\,.*>.*',
                  '.*-StaticAssertDecl\sHexnumber\s<.*\,.*>.*',
                  '.*-ConditionalOperator\sHexnumber\s<.*\,.*>.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'\*\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'\/\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'\-\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'\+\'.*',
                  '.*UnaryOperator Hexnumber <.*\,.*>.*\'\+\+\'.*',
                  '.*UnaryOperator Hexnumber <.*\,.*>.*\'\-\-\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'\&\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'\|\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'=\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'<\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'>\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'==\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'!=\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'>=\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'<=\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'\&\&\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'\|\|\'.*',
                  '.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\+\=\'.*',
                  '.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\-\=\'.*',
                  '.*ReturnStmt Hexnumber <.*\,.*>.*']

# Modes:
#  1    Contained space, use as is
#  2    Free, need to look for next
#  x    Free, look for next at colpos + x
exppatternmode = [1,1,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,6]
