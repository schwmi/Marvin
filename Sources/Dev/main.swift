import Marvin


let marvin = try Marvin(skills: [BasicSkills.Greet()])
try marvin.run()
