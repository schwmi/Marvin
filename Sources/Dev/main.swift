import Marvin


let marvin = try Marvin(skills: [BasicSkills.Greet()], environment: .detect())
try marvin.run()
