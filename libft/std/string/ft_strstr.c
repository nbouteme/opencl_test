/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   ft_strstr.c                                        :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: nbouteme <marvin@42.fr>                    +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2015/11/25 18:57:57 by nbouteme          #+#    #+#             */
/*   Updated: 2015/11/25 18:58:03 by nbouteme         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

char	*ft_strstr(const char *s1, const char *s2)
{
	int a;
	int b;

	if (!*s2)
		return ((char*)s1);
	a = 0;
	while (s1[a])
	{
		if (s1[a] == s2[0])
		{
			b = 0;
			while (s2[b] && s1[a + b] && s1[a + b] == s2[b])
				++b;
			if (!s2[b])
				return ((char *)&s1[a]);
		}
		a++;
	}
	return (0);
}
