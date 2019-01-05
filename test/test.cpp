// make sure the modern opengl headers are included before any others
#include <OpenGL/gl3.h>
#define __gl_h_
#include <igl/frustum.h>
#include <igl/read_triangle_mesh.h>
#include <igl/opengl/create_shader_program.h>
#include <Eigen/Core>
#include <GLUT/glut.h>
#include <string>

void init_render_to_texture(
  const size_t w, const size_t h, GLuint & tex, GLuint & dtex, GLuint & fbo)
{
  const auto & gen_tex = [](GLuint & tex)
  {
    // http://www.opengl.org/wiki/Framebuffer_Object_Examples#Quick_example.2C_render_to_texture_.282D.29
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  };
  // Generate texture for colors and attached to color component of framebuffer
  gen_tex(tex);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, w, h, 0, GL_BGRA, GL_FLOAT, NULL);
  glBindTexture(GL_TEXTURE_2D, 0);
  glGenFramebuffers(1, &fbo);
  glBindFramebuffer(GL_FRAMEBUFFER, fbo);
  // Generate texture for depth and attached to depth component of framebuffer
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex, 0);
  gen_tex(dtex);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT32, w, h, 0, GL_DEPTH_COMPONENT, GL_FLOAT, NULL);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, dtex, 0);
  // Clean up
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  glBindTexture(GL_TEXTURE_2D,0);
}


// For rendering a full-viewport quad, set tex-coord from position
std::string tex_v_shader = R"(
#version 330 core
in vec3 position;
out vec2 tex_coord;
void main()
{
  gl_Position = vec4(position,1.);
  tex_coord = vec2(0.5*(position.x+1), 0.5*(position.y+1));
}
)";
// Render directly from color or depth texture
std::string tex_f_shader = R"(
#version 330 core
in vec2 tex_coord;
out vec4 color;
uniform sampler2D color_texture;
uniform sampler2D depth_texture;
uniform bool show_depth;
void main()
{
  vec4 depth = texture(depth_texture,tex_coord);
  // Mask out background which is set to 1
  if(depth.r<1)
  {
    color = texture(color_texture,tex_coord);
    if(show_depth)
    {
      // Depth of background seems to be set to exactly 1.
      color.rgb = vec3(1,1,1)*(1.-depth.r)/0.006125;
    }
  }else
  {
    discard;
  }
}
)";

// Pass-through vertex shader with projection and model matrices
std::string scene_v_shader = R"(
#version 330 core
uniform mat4 proj;
uniform mat4 model;
in vec3 position;
void main()
{
  gl_Position = proj * model * vec4(position,1.);
}
)";
// Render if first pass or farther than closest frag on last pass
std::string scene_f_shader = R"(
#version 330 core
out vec4 color;
uniform bool first_pass;
uniform float width;
uniform float height;
uniform sampler2D depth_texture;
void main()
{
  color = vec4(0.8,0.4,0.0,0.75);
  color.rgb *= (1.-gl_FragCoord.z)/0.006125;
  if(!first_pass)
  {
    vec2 tex_coord = vec2(float(gl_FragCoord.x)/width,float(gl_FragCoord.y)/height);
    float max_depth = texture(depth_texture,tex_coord).r;
    if(gl_FragCoord.z <= max_depth)
    {
      discard;
    }
  }
}
)";

// shader id, vertex array object
GLuint scene_p_id=0,tex_p_id;
GLuint VAO,QVAO;
// Number of passes
#define k 4
GLuint tex_id[k],dtex_id[k],fbo_id[k];
// full width/height of window, width/height of viewports
int full_w=1440,full_h=480,w=full_w/(k+2),h=full_h/1;
// Mesh data: RowMajor is important to directly use in OpenGL
typedef Eigen::Matrix< float,Eigen::Dynamic,3,Eigen::RowMajor> MatrixV;
typedef Eigen::Matrix<GLuint,Eigen::Dynamic,3,Eigen::RowMajor> MatrixF;
MatrixV V,QV;
MatrixF F,QF;
int main(int argc, char * argv[])
{
  // Init glut and create window + OpenGL context
  glutInit(&argc,argv);
  glutInitDisplayMode(GLUT_3_2_CORE_PROFILE|GLUT_RGBA|GLUT_DOUBLE|GLUT_DEPTH);
  glutInitWindowSize(full_w,full_h);
  glutCreateWindow("test");
  // Compile shaders
  igl::opengl::create_shader_program(scene_v_shader,scene_f_shader,{},scene_p_id);
  igl::opengl::create_shader_program(tex_v_shader,tex_f_shader,{},tex_p_id);
  // Prepare VAOs
  const auto & vao = [](const MatrixV & V, const MatrixF & F, GLuint & VAO)
  {
    // Generate and attach buffers to vertex array
    glGenVertexArrays(1, &VAO);
    GLuint VBO, EBO;
    glGenBuffers(1, &VBO);
    glGenBuffers(1, &EBO);
    glBindVertexArray(VAO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(float)*V.size(), V.data(), GL_STATIC_DRAW);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(GLuint)*F.size(), F.data(), GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(GLfloat), (GLvoid*)0);
    glEnableVertexAttribArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
  };

  // Read input mesh from file
  igl::read_triangle_mesh(argv[1],V,F);
  V.rowwise() -= V.colwise().mean();
  V /= (V.colwise().maxCoeff()-V.colwise().minCoeff()).maxCoeff();
  vao(V,F,VAO);
  // square
  const MatrixV QV = (MatrixV(4,3)<<-1,-1,0,1,-1,0,1,1,0,-1,1,0).finished();
  const MatrixF QF = (MatrixF(2,3)<< 0,1,2, 0,2,3).finished();
  vao(QV,QF,QVAO);

  // Main display routine
  glutDisplayFunc(
    []()
    {
      // Projection and modelview matrices
      Eigen::Matrix4f proj = Eigen::Matrix4f::Identity();
      float near = 0.01;
      float far = 3;
      float top = tan(35./360.*M_PI)*near;
      float right = top * (double)w/(double)h;
      igl::frustum(-right,right,-top,top,near,far,proj);
      Eigen::Affine3f model = Eigen::Affine3f::Identity();
      model.translate(Eigen::Vector3f(0,0,-1.5));
      // spin around
      static size_t count = 0;
      model.rotate(Eigen::AngleAxisf(M_PI/180.*count++,Eigen::Vector3f(0,1,0)));

      glEnable(GL_DEPTH_TEST);
      glViewport(0,0,w,h);
      // select program and attach uniforms
      glUseProgram(scene_p_id);
      GLint proj_loc = glGetUniformLocation(scene_p_id,"proj");
      glUniformMatrix4fv(proj_loc,1,GL_FALSE,proj.data());
      GLint model_loc = glGetUniformLocation(scene_p_id,"model");
      glUniformMatrix4fv(model_loc,1,GL_FALSE,model.matrix().data());
      glUniform1f(glGetUniformLocation(scene_p_id,"width"),w);
      glUniform1f(glGetUniformLocation(scene_p_id,"height"),h);
      glBindVertexArray(VAO);
      glDisable(GL_BLEND);
      for(int pass = 0;pass<k;pass++)
      {
        const bool first_pass = pass == 0;
        glUniform1i(glGetUniformLocation(scene_p_id,"first_pass"),first_pass);
        if(!first_pass)
        {
          glUniform1i(glGetUniformLocation(scene_p_id,"depth_texture"),0);
          glActiveTexture(GL_TEXTURE0 + 0);
          glBindTexture(GL_TEXTURE_2D, dtex_id[pass-1]);
        }
        glBindFramebuffer(GL_FRAMEBUFFER, fbo_id[pass]);
        glClearColor(0.0,0.4,0.7,0.);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glDrawElements(GL_TRIANGLES, F.size(), GL_UNSIGNED_INT, 0);
      }
      // clean up and set to render to screen
      glBindVertexArray(0);
      glBindFramebuffer(GL_FRAMEBUFFER, 0);
      glActiveTexture(GL_TEXTURE0 + 0);
      glBindTexture(GL_TEXTURE_2D,0);

      // Get read to draw quads
      glBindVertexArray(QVAO);
      glClearColor(0.0,0.4,0.7,0.);
      glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
      glUseProgram(tex_p_id);
      // Draw result of each peel
      for(int pass = 0;pass<k;pass++)
      {
        GLint color_tex_loc = glGetUniformLocation(tex_p_id,"color_texture");
        glUniform1i(color_tex_loc, 0);
        glActiveTexture(GL_TEXTURE0 + 0);
        glBindTexture(GL_TEXTURE_2D, tex_id[pass]);
        GLint depth_tex_loc = glGetUniformLocation(tex_p_id,"depth_texture");
        glUniform1i(depth_tex_loc, 1);
        glActiveTexture(GL_TEXTURE0 + 1);
        glBindTexture(GL_TEXTURE_2D, dtex_id[pass]);
        glViewport(pass*w,0*h,w,h);
        glUniform1i(glGetUniformLocation(tex_p_id,"show_depth"),0);
        glDrawElements(GL_TRIANGLES,6, GL_UNSIGNED_INT, 0);
      }

      // Render final result as composite of all textures
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
      glEnable(GL_BLEND);
      glDepthFunc(GL_ALWAYS);
      glViewport(k*w,0*h,w,h);
      glUniform1i(glGetUniformLocation(tex_p_id,"show_depth"),0);
      GLint color_tex_loc = glGetUniformLocation(tex_p_id,"color_texture");
      GLint depth_tex_loc = glGetUniformLocation(tex_p_id,"depth_texture");
      for(int pass = k-1;pass>=0;pass--)
      {
        glUniform1i(color_tex_loc, 0);
        glActiveTexture(GL_TEXTURE0 + 0);
        glBindTexture(GL_TEXTURE_2D, tex_id[pass]);
        glUniform1i(depth_tex_loc, 1);
        glActiveTexture(GL_TEXTURE0 + 1);
        glBindTexture(GL_TEXTURE_2D, dtex_id[pass]);
        glDrawElements(GL_TRIANGLES,6, GL_UNSIGNED_INT, 0);
      }
      glDepthFunc(GL_LESS);
      // Render scene using naive GL_BLEND transparency
      glUseProgram(scene_p_id);
      glBindVertexArray(VAO);
      glViewport((k+1)*w,0*h,w,h);
      glDrawElements(GL_TRIANGLES, F.size(), GL_UNSIGNED_INT, 0);
      glBindVertexArray(0);
      glDisable(GL_BLEND);

      glutSwapBuffers();
      glutPostRedisplay();
    }
    );
  glutReshapeFunc(
    [](int w,int h)
    {
      full_h=h;
      full_w=w;
      ::w=full_w/(k+2);
      ::h=full_h/(1);
      // (re)-initialize textures and buffers
      for(size_t i = 0;i<k;i++)
      {
        init_render_to_texture(::w,::h,tex_id[i],dtex_id[i],fbo_id[i]);
      }
    });
  glutMainLoop();
}
