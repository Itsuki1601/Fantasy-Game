using Godot;

public partial class PlayerMovementController : CharacterBody3D
{
    // How fast the player moves in meters per second
    [Export]
    public int WalkingSpeed { get; set; } = 14;

    // The downward acceleration when in the air, in meters per second
    [Export]
    public int FallAcceleration { get; set; } = 75;

    private Vector3 _targetVelocity = Vector3.Zero;

    public override void _PhysicsProcess(double delta)
    {
        // Input direction
        var direction = Vector3.Zero;

        // Check for each movement input and update accordingly
        if (Input.IsActionPressed("strafe_right"))
        {
            direction.X += 1.0f;
        }
        if (Input.IsActionPressed("strafe_left"))
        {
            direction.X -= 1.0f;
        }
        if (Input.IsActionPressed("move_forward"))
        {
            direction.Z += 1.0f;
        }
        if (Input.IsActionPressed("move_backward"))
        {
            direction.Z -= 1.0f;
        }

        if (direction != Vector3.Zero)
        {
            direction = direction.Normalized();
            // Setting the basis properly will affect the rotation of the node
            GetNode<Node3D>("Pivot").Basis = Basis.LookingAt(direction);
        }

        // Ground velocity
        _targetVelocity.X = direction.X * WalkingSpeed;
        _targetVelocity.Y = direction.Y * WalkingSpeed;

        // Verticle velocity
        if (!IsOnFloor())
        {
            _targetVelocity.Y -= FallAcceleration * (float)delta;
        }

        // Moving the character
        Velocity = _targetVelocity;
        MoveAndSlide();
    }
}
