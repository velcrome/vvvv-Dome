#region usings
using System;
using System.ComponentModel.Composition;

using Microsoft.SolverFoundation.Solvers;
using Microsoft.SolverFoundation.Common;
using Microsoft.SolverFoundation.Services;

using System.Collections.Generic;
using System.Linq;

using VVVV.PluginInterfaces.V1;
using VVVV.PluginInterfaces.V2;
using VVVV.Utils.VMath;
using VVVV.Core.Logging; 
#endregion usings

namespace VVVV.Nodes
{
	#region PluginInfo
	[PluginInfo(Name = "Solver", Category = "3d", Help = "Reconstructs a Beamers intrinsics and extrinsics by a bunch of mapped points", Tags = "Mapping, Camera, Projector", Author = "velcrome")]
	#endregion PluginInfo
	public class Vector3DSolverNode : IPluginEvaluate, IPartImportsSatisfiedNotification
	{
		#region fields & pins

		[Input("Input", DefaultValues = new[] {0.0, 0, 0})]
		public ISpread<Vector3D> FReal;

		[Input("Mapped")]
		public ISpread<Vector2D> FMapped;		

		[Input("Estimated Position", DefaultValues = new double[] {0, 3, 0}, Visibility = PinVisibility.OnlyInspector)]
		public ISpread<Vector3D> FEstimatedPosition;		
		
		[Input("Position Tolerance", DefaultValue = 30.0, Visibility = PinVisibility.OnlyInspector)]
		public ISpread<double> FTolerancePosition;		
		
		[Input("Solve", IsBang = true)]
		public IDiffSpread<bool> FCalc;		

/////////////////////		
		
		[Output("Translate")]
		public ISpread<Vector3D> FTranslate;

		[Output("Rotate")]
		public ISpread<Vector3D> FRotate;

		[Output("Shift")]
		public ISpread<Vector2D> FShift;
		
		[Output("FoV")]
		public ISpread<double> FFov;		
		
		[Output("Error")]
		public ISpread<double> FError;		

		[Import()]
		public ILogger FLogger;
		
        [Import()]
        public IPluginHost2 FHost;
		
		private List<NelderMeadSolver> Solvers = new List<NelderMeadSolver>();
		private NelderMeadSolverParams Configuration;
		
		private const int dimensions = 9;
		private bool firstFrame = true;
		
		#endregion fields & pins

		
		public virtual void OnImportsSatisfied()
        {	
       	
		}
		
		public NelderMeadSolver Init() { 
			var solver = new NelderMeadSolver();
			
			int vidRow;
			solver.AddRow(null, out vidRow);
			solver.AddGoal(vidRow, 0, true);
			
			int[] vidVariables = new int[dimensions];
			for (int i=0;i<dimensions;i++) 			
				solver.AddVariable(null, out vidVariables[i]);

			solver.FunctionEvaluator = DiffMapping;
			
			Solvers.Clear();
			Solvers.Add(solver);
			
			return solver;
		}

		public void Config(NelderMeadSolver solver) {
			Configuration = new NelderMeadSolverParams();

			Vector3D pos = FEstimatedPosition[0];
			Vector3D min = pos - 0.5 * FTolerancePosition[0];
			Vector3D max = pos + 0.5 * FTolerancePosition[0];

			solver.SetBounds(1, min.x, max.x); // translation
			solver.SetBounds(2, min.y, max.y);
			solver.SetBounds(3, min.z, max.z);
			
			for (int b=4;b<=6;b++) solver.SetBounds(b, -0.5, 0.5); // rotation
			
			solver.SetBounds(7, 0.05, 0.49); // fov
			solver.SetBounds(8, -1, 1); // shift x
			solver.SetBounds(9, -1, 1); // shift y


			solver.SetValue(1, pos.x );
			solver.SetValue(2, pos.y );
			solver.SetValue(3, pos.z );

			solver.SetValue(4, VMath.Map(VMath.Random.Next(100), 0, 100, -0.05, 0.05, TMapMode.Float) );
			solver.SetValue(5, VMath.Map(VMath.Random.Next(100), 0, 100, -0.05, 0.05, TMapMode.Float) );
			solver.SetValue(6, VMath.Map(VMath.Random.Next(100), 0, 100, -0.05, 0.05, TMapMode.Float) );

			solver.SetValue(7, 0.01);
			solver.SetValue(8, 0.01);
			solver.SetValue(9, 0.20);			
		}
		
		
		//called when data for any output pin is requested
		public void Evaluate(int SpreadMax)
		{
			if ( !(FCalc.SliceCount > 0 && FCalc[0]) && !firstFrame ) return;

			SpreadMax = 1;
			FTranslate.SliceCount 	= 
			FRotate.SliceCount 		=
			FFov.SliceCount			=
			FShift.SliceCount 		= 
			FError.SliceCount		= SpreadMax; 

			
			if ((FCalc.IsChanged && FCalc[0]) || firstFrame) {
				
				Config(Init());
				firstFrame = false;
			}

			var Solver = Solvers[0];
			var solution = Solver.Solve(Configuration);
			

			double[] v = new double[dimensions];
			for (int i=0;i<dimensions;i++) {
				v[i] = Solver.GetValue(i+1).ToDouble();
			}

			
			var translate 	= new Vector3D(v[0], v[1], v[2]);
			var rotate		= new Vector3D(v[3], v[4], v[5]);
			var fov 		= v[6];
			var shift 		= new Vector2D(v[7], v[8]);						
			
			FTranslate[0] = translate;
			FRotate[0] = rotate;
			FFov[0] = fov;
			FShift[0] = shift;

//			FLogger.Log(LogType.Debug, "Merke: " + Solver.GetReport().ToString());
			FError[0] = Solver.GetSolutionValue(0);
		}

		private double DiffMapping(INonlinearModel model, int rowVid, ValuesByIndex v, bool newValues) {
			int a = 1;
			var translate 	= new Vector3D(v[0+a], v[1+a], v[2+a]);
			var rotate		= new Vector3D(v[3+a], v[4+a], v[5+a]);
			var fov 		= v[6+a];
			var shift 		= new Vector2D(v[7+a], v[8+a]);			
			
			double sum = 0;
			int i = 0;
			foreach (var r in FReal) {
				var result = Project(r, translate, rotate, fov, shift) - FMapped[i];
				sum += result.x * result.x + result.y * result.y;
				i++;
			}
			return sum; // of least squares			
		}
		
	
		protected Vector2D ProjectVertex(Vector3D pos, Matrix4x4 viewproj) {
			var tmp = viewproj * pos;
			return new Vector2D( tmp.x, tmp.y);
		}
		
		
		public Vector2D Project(Vector3D pos, Vector3D translate, Vector3D rotate, double fov, Vector2D shift, double Aspect = 0.75, double Near = 0.5, double Far = 100) {

			//			VMath.Rotate expects Radians
			var view = VMath.Inverse( VMath.Rotate(rotate * Math.PI * 2) * VMath.Translate(translate)   );

			double scaleX = 1.0/Math.Tan(fov * Math.PI);
			double scaleY = scaleX / Aspect;
			double fn = Far / (Far - Near);
			
			var proj = new Matrix4x4(scaleX,      	0,      	0, 			0,
			                          0, 			scaleY, 	0, 			0,
			                          -2*shift.x, 	-2*shift.y, fn, 		1,
			                          0,      		0, 			-Near*fn, 	0);


			return ProjectVertex(pos, view * proj);
		}		
		
	}
	

	
	
}
