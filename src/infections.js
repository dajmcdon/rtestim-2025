<script>
function init () {
const canvas = document.getElementById("simulation");
const ctx = canvas.getContext("2d");

const BALL_COUNT = 20;
const BALL_RADIUS = 15;
const SPEED = 2;
let balls = [];

class Ball {
  constructor(x, y, color, generation = 0) {
    this.x = x;
    this.y = y;
    this.color = color;
    this.generation = generation;
    this.dx = (Math.random() * 2 - 1) * SPEED;
    this.dy = (Math.random() * 2 - 1) * SPEED;
  }

  move() {
    this.x += this.dx;
    this.y += this.dy;

    if (this.x - BALL_RADIUS < 0 || this.x + BALL_RADIUS > canvas.width) {
      this.dx *= -1;
    }
    if (this.y - BALL_RADIUS < 0 || this.y + BALL_RADIUS > canvas.height) {
      this.dy *= -1;
    }
  }

  draw() {
    ctx.beginPath();
    ctx.arc(this.x, this.y, BALL_RADIUS, 0, Math.PI * 2);
    ctx.fillStyle = this.color;
    ctx.fill();
    ctx.closePath();
  }

  isTouching(other) {
    const dist = Math.hypot(this.x - other.x, this.y - other.y);
    return dist < BALL_RADIUS * 2;
  }

  lightenColor() {
    const redValue = Math.min(255, 100 + this.generation * 40);
    return `rgb(${redValue}, 0, 0)`;
  }
}

function allInfected() {
  return balls.every(ball => ball.color.startsWith("rgb("));
}

function reset() {
  balls = [];
  init();
}

function init() {
}

function update() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  balls.forEach((ball, index) => {
    ball.move();
    ball.draw();
    balls.forEach((other, otherIndex) => {
      if (index !== otherIndex && ball.isTouching(other) && ball.color.startsWith("rgb(") && other.color === "blue") {
        other.generation = ball.generation + 1;
        other.color = other.lightenColor();
      }
    });
  });

  if (allInfected()) {
    setTimeout(reset, 2000);
  } else {
    requestAnimationFrame(update);
  }
}

balls.push(new Ball(Math.random() * canvas.width, Math.random() * canvas.height, "rgb(100, 0, 0)", 0));
  for (let i = 1; i < BALL_COUNT; i++) {
    balls.push(new Ball(Math.random() * canvas.width, Math.random() * canvas.height, "blue"));
  }
  requestAnimationFrame(update);
}
</script>