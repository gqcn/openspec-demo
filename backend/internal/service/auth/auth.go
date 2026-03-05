// Package auth provides authentication services including JWT generation and validation.
package auth

import (
	"context"
	"time"

	"github.com/gogf/gf/v2/errors/gcode"
	"github.com/gogf/gf/v2/errors/gerror"
	"github.com/gogf/gf/v2/frame/g"
	"github.com/golang-jwt/jwt/v5"
	"github.com/gqcn/platform/backend/internal/consts"
	"github.com/gqcn/platform/backend/internal/dao"
	"github.com/gqcn/platform/backend/internal/model/entity"
	"golang.org/x/crypto/bcrypt"
)

// PlatformClaims extends jwt.RegisteredClaims for this application.
type PlatformClaims struct {
	UserId   uint   `json:"userId"`
	Username string `json:"username"`
	IsAdmin  uint   `json:"isAdmin"`
	Uid      uint   `json:"uid"`
	jwt.RegisteredClaims
}

// Login verifies credentials and returns a signed JWT token.
func Login(ctx context.Context, username, password string) (token string, err error) {
	var user *entity.User
	err = dao.Users.Ctx(ctx).Where("username", username).Where("status", 1).Scan(&user)
	if err != nil {
		return "", gerror.NewCode(gcode.CodeInternalError, "数据库查询失败")
	}
	if user == nil {
		return "", gerror.NewCode(gcode.CodeNotAuthorized, "用户名或密码错误")
	}
	if err = bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		return "", gerror.NewCode(gcode.CodeNotAuthorized, "用户名或密码错误")
	}

	expireHour := g.Cfg().MustGet(ctx, "jwt.expireHour", 24).Int()
	claims := PlatformClaims{
		UserId:   user.Id,
		Username: user.Username,
		IsAdmin:  user.IsAdmin,
		Uid:      user.Uid,
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    consts.JWTIssuer,
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Duration(expireHour) * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	secret := g.Cfg().MustGet(ctx, "jwt.secret", "changeme").String()
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return t.SignedString([]byte(secret))
}

// ParseToken parses and validates the JWT token, returning its claims.
func ParseToken(ctx context.Context, tokenStr string) (*PlatformClaims, error) {
	secret := g.Cfg().MustGet(ctx, "jwt.secret", "changeme").String()
	t, err := jwt.ParseWithClaims(tokenStr, &PlatformClaims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, gerror.New("unexpected signing method")
		}
		return []byte(secret), nil
	})
	if err != nil || !t.Valid {
		return nil, gerror.NewCode(gcode.CodeNotAuthorized, "token 无效或已过期")
	}
	claims, ok := t.Claims.(*PlatformClaims)
	if !ok {
		return nil, gerror.NewCode(gcode.CodeNotAuthorized, "token 解析失败")
	}
	return claims, nil
}

// HashPassword generates a bcrypt hash for the given plain-text password.
func HashPassword(password string) (string, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}
	return string(hash), nil
}
